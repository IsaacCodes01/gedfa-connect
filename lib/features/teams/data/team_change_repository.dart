import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/name_match.dart';
import 'package:gedfa_connect/core/utils/team_name_key.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/teams/data/team_profile_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';

const _timeout = Duration(seconds: 15);
const _uploadTimeout = Duration(seconds: 60);

/// Change requests (2.10b): the team asks, the FA approves or refuses.
///
/// Think of it as a form handed in at the FA's office: the team fills it
/// in (what, the new value, why), and nothing about the club changes
/// until the FA stamps it. Approving does the change and stamps the form
/// in ONE batch, so they can never disagree.
class TeamChangeRepository {
  TeamChangeRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _changeRef(String id) =>
      _db.doc(FirestorePaths.teamChange(id));

  List<TeamChange> _list(QuerySnapshot<Map<String, dynamic>> snapshot) => [
        for (final doc in snapshot.docs) TeamChange.fromMap(doc.id, doc.data()),
      ];

  /// A team's own requests (at most one of each kind), live.
  Stream<List<TeamChange>> watchForTeam(String teamId) => _db
      .collection(FirestorePaths.teamChanges)
      .where('teamId', isEqualTo: teamId)
      .snapshots()
      .map(_list);

  /// FA: every request in the district, live. Sorted in the app.
  Stream<List<TeamChange>> watchAll() =>
      _db.collection(FirestorePaths.teamChanges).snapshots().map(_list);

  Stream<TeamChange?> watch(String id) =>
      _changeRef(id).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : TeamChange.fromMap(doc.id, data);
      });

  // ---------- The team asks ----------

  /// Uploads the logo the team asks for: `teams/{teamId}/logo-<time>.jpg`.
  /// It is only used once the FA approves it.
  Future<String> uploadLogo({
    required String teamId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final name = 'logo-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref(StoragePaths.teamLogo(teamId, name));
    await ref
        .putData(bytes, SettableMetadata(contentType: contentType))
        .timeout(_uploadTimeout);
    return ref.getDownloadURL();
  }

  /// Sends the request and tells the FA, in one batch. [to] is the new
  /// name, short name, logo link, or the competition to add.
  Future<void> ask({
    required String teamId,
    required TeamDetails team,
    required TeamChangeKind kind,
    required String to,
    required String reason,
    required String askedBy,
    String? askedByName,
  }) async {
    final nameKey = kind == TeamChangeKind.name ? teamNameKey(to) : null;

    // Checked before sending, so the team gets a clear message (the
    // rules refuse it too). The club's own old names are fine.
    if (nameKey != null) {
      final reservation =
          await _db.doc(FirestorePaths.teamName(nameKey)).get().timeout(_timeout);
      if (reservation.exists && reservation.data()?['uid'] != team.uid) {
        throw const TeamNameTakenException();
      }
    }

    final change = TeamChange(
      id: TeamChange.idFor(teamId, kind),
      teamId: teamId,
      teamName: team.teamName,
      kind: kind,
      to: to,
      reason: reason,
      status: ApprovalStatus.pending,
    );
    final batch = _db.batch()
      ..set(_changeRef(change.id), {
        'teamId': teamId,
        'teamName': team.teamName,
        'kind': kind.name,
        // The value now, for the FA's "Now"
        'from': switch (kind) {
          TeamChangeKind.name => team.teamName,
          TeamChangeKind.shortName => team.shortName,
          TeamChangeKind.logo => team.logoUrl,
          TeamChangeKind.competition => Competition.toList(team.categories),
        },
        'to': to,
        'nameKey': ?nameKey,
        'reason': reason,
        'status': ApprovalStatus.pending.name,
        'askedBy': askedBy,
        'askedByName': ?askedByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    // The FA's bell: "Golden Unity FC asked for a change"
    NotificationWriter(_db).forFaInBatch(
      batch,
      kind: NotificationKind.changeRequested,
      teamId: teamId,
      teamName: team.teamName,
      name: change.summary,
    );
    await batch.commit().timeout(_timeout);
  }

  // ---------- The FA decides ----------

  Map<String, dynamic> _decision(ApprovalStatus status, String faUid) => {
        'status': status.name,
        'reviewedBy': faUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// FA approves [change]. In ONE batch (all or nothing):
  /// 1. the request is approved,
  /// 2. the team gets the new name / short name / logo / competition,
  /// 3. a new name: every player's copy of the team name follows (their
  ///    IDs never change) and the name is reserved for the club,
  /// 4. the team's bell: "Change approved".
  Future<void> approve(TeamChange change, {required String faUid}) async {
    final teamRef = _db.doc(FirestorePaths.team(change.teamId));
    final team = (await teamRef.get().timeout(_timeout)).data();
    if (team == null) throw StateError('Team ${change.teamId} not found');

    final batch = _db.batch()
      ..update(_changeRef(change.id), _decision(ApprovalStatus.approved, faUid));
    final updatedAt = FieldValue.serverTimestamp();
    var teamName = team['name'] as String? ?? change.teamName;

    switch (change.kind) {
      case TeamChangeKind.name:
        final requestUid = team['requestUid'] as String?;
        final key = change.nameKey ?? teamNameKey(change.to);
        final nameRef = _db.doc(FirestorePaths.teamName(key));
        // Read BEFORE the batch, so the FA gets a clear message
        final reservation = await nameRef.get().timeout(_timeout);
        if (reservation.exists && reservation.data()?['uid'] != requestUid) {
          throw const TeamNameTakenException();
        }
        final players = await _db
            .collection(FirestorePaths.players)
            .where('teamId', isEqualTo: change.teamId)
            .get()
            .timeout(_timeout);

        teamName = change.to;
        batch.update(teamRef, {
          'name': teamName,
          'nameLower': teamName.toLowerCase(),
          'updatedAt': updatedAt,
        });
        if (!reservation.exists) {
          batch.set(nameRef, {
            'uid': requestUid,
            'teamId': change.teamId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        for (final player in players.docs) {
          if (player.data()['teamName'] != teamName) {
            batch.update(player.reference, {'teamName': teamName});
          }
        }
      case TeamChangeKind.shortName:
        batch.update(teamRef, {'shortName': change.to, 'updatedAt': updatedAt});
      case TeamChangeKind.logo:
        batch.update(teamRef, {'logoUrl': change.to, 'updatedAt': updatedAt});
      case TeamChangeKind.competition:
        final now =
            Competition.fromList(team['categories'] as List<dynamic>?);
        final added = change.competition ?? Competition.juvenile;
        batch.update(teamRef, {
          'categories': Competition.toList({...now, added}),
          // A Juvenile-only club's kits are its juvenile kits; they stay
          // as its Division kits too until it edits them.
          if (added == Competition.division) 'juvenileKits': team['kits'],
          'updatedAt': updatedAt,
        });
    }

    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.changeApproved,
      teamId: change.teamId,
      teamName: teamName,
      name: change.summary,
    );
    await batch.commit().timeout(_timeout);
  }

  /// FA rejects: the team sees [reason] on its team page.
  Future<void> refuse(
    TeamChange change, {
    required String reason,
    required String faUid,
  }) {
    final batch = _db.batch()
      ..update(_changeRef(change.id), {
        ..._decision(ApprovalStatus.rejected, faUid),
        'rejectionReason': reason.trim(),
      });
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.changeRefused,
      teamId: change.teamId,
      teamName: change.teamName,
      name: change.summary,
    );
    return batch.commit().timeout(_timeout);
  }
}

final teamChangeRepositoryProvider = Provider<TeamChangeRepository>((ref) {
  return TeamChangeRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  );
});

/// The signed-in team admin's requests (at most one of each kind).
final myTeamChangesProvider = StreamProvider<List<TeamChange>>((ref) async* {
  final appUser = await ref.watch(appUserProvider.future);
  final teamId = appUser?.teamId;
  if (teamId == null || teamId.isEmpty) {
    yield const [];
    return;
  }
  yield* ref.watch(teamChangeRepositoryProvider).watchForTeam(teamId);
});

/// FA: every change request, live.
final allTeamChangesProvider = StreamProvider<List<TeamChange>>((ref) {
  return ref.watch(teamChangeRepositoryProvider).watchAll();
});

/// FA: one change request, live.
final teamChangeProvider =
    StreamProvider.family<TeamChange?, String>((ref, id) {
  return ref.watch(teamChangeRepositoryProvider).watch(id);
});

/// FA: how many TEAMS have changes waiting (one card each, 2.10c).
final pendingTeamChangeCountProvider = Provider<int>((ref) {
  final changes = ref.watch(allTeamChangesProvider).value ?? const [];
  return {
    for (final change in changes)
      if (change.isPending) change.teamId,
  }.length;
});

/// FA: an approved team as it is NOW, and its name before the latest
/// approved rename (null if it still has its registered name). For the
/// Approved tiles: "Previously Golden Unity FC" (2.10c).
typedef CurrentTeam = ({Team team, String? previousName});

/// The key is a record (team ID + the name it registered with), so the
/// same team reuses the same answer.
final currentTeamProvider = Provider.family<CurrentTeam?,
    ({String teamId, String registeredName})>((ref, key) {
  final teams = ref.watch(allTeamsProvider).value ?? const <Team>[];
  final team = teams.where((t) => t.id == key.teamId).firstOrNull;
  if (team == null) return null;
  if (team.name == key.registeredName) return (team: team, previousName: null);

  // Renamed: the name it had just before (it may have been renamed twice)
  final changes = ref.watch(allTeamChangesProvider).value ?? const [];
  final rename = changes
      .where((c) =>
          c.teamId == key.teamId &&
          c.kind == TeamChangeKind.name &&
          c.status == ApprovalStatus.approved &&
          c.to == team.name)
      .firstOrNull;
  return (team: team, previousName: rename?.from ?? key.registeredName);
});

/// FA: the gold number on the Teams tab: new teams + changes waiting.
final faTeamsWaitingCountProvider = Provider<int>((ref) {
  return ref.watch(pendingTeamRequestCountProvider) +
      ref.watch(pendingTeamChangeCountProvider);
});

/// The app's check of a new name for the FA: is it reserved by another
/// club, or very close to another team's name?
typedef NameCheck = ({bool taken, String? similarTo});

/// The key is a record, so the same team + name reuses the same answer.
final nameCheckProvider =
    FutureProvider.family<NameCheck, ({String teamId, String name})>(
        (ref, key) async {
  final teams = await ref.watch(allTeamsProvider.future);
  final team = teams.where((t) => t.id == key.teamId).firstOrNull;
  final reservation = await ref
      .watch(firestoreProvider)
      .doc(FirestorePaths.teamName(teamNameKey(key.name)))
      .get()
      .timeout(_timeout);
  final taken = reservation.exists &&
      reservation.data()?['uid'] != team?.requestUid;
  final similar = teams
      .where((t) => t.id != key.teamId && similarNames(t.name, key.name))
      .firstOrNull;
  return (taken: taken, similarTo: similar?.name);
});
