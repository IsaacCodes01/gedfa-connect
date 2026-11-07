import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/team_name_key.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/teams/domain/team_correction.dart';

const _timeout = Duration(seconds: 15);

/// The FA corrects a mistake on an approved team itself (2.11a).
///
/// Like a correction in a register with a pen: the FA crosses out the
/// wrong value, writes the right one, and signs the margin with why. The
/// team, the signed note (the log line) and the team's bell are ONE batch,
/// so a correction is never made without its note.
class TeamCorrectionRepository {
  TeamCorrectionRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _log(String teamId) =>
      _db.collection(FirestorePaths.teamCorrections(teamId));

  /// A team's corrections, newest first, live.
  Stream<List<TeamCorrection>> watch(String teamId) => _log(teamId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => [
            for (final doc in snapshot.docs)
              TeamCorrection.fromMap(doc.id, doc.data()),
          ]);

  /// Saves [changes] (team fields) with a log line. [lines] say what
  /// changed ("Home ground: Apam Prk → Apam Park"); [reason] is "What was
  /// wrong?". A new club name ([CorrectionSection.name]) is also reserved
  /// for the club and copied onto every player (their IDs never change).
  Future<void> correct({
    required String teamId,
    required String teamName,
    required CorrectionSection section,
    required Map<String, dynamic> changes,
    required List<String> lines,
    required String reason,
    required String faUid,
    String? faName,
  }) async {
    final teamRef = _db.doc(FirestorePaths.team(teamId));
    final logRef = _log(teamId).doc();
    final batch = _db.batch();
    var fields = changes;
    var newTeamName = teamName;
    String? nameKey;

    if (section == CorrectionSection.name) {
      newTeamName = (changes['name'] as String).trim();
      nameKey = teamNameKey(newTeamName);
      // Read BEFORE the batch, so the FA gets a clear message
      final team = (await teamRef.get().timeout(_timeout)).data();
      final requestUid = team?['requestUid'] as String?;
      final nameRef = _db.doc(FirestorePaths.teamName(nameKey));
      final reservation = await nameRef.get().timeout(_timeout);
      if (reservation.exists && reservation.data()?['uid'] != requestUid) {
        throw const TeamNameTakenException();
      }
      final players = await _db
          .collection(FirestorePaths.players)
          .where('teamId', isEqualTo: teamId)
          .get()
          .timeout(_timeout);

      fields = {'name': newTeamName, 'nameLower': newTeamName.toLowerCase()};
      if (!reservation.exists) {
        batch.set(nameRef, {
          'uid': requestUid,
          'teamId': teamId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      for (final player in players.docs) {
        if (player.data()['teamName'] != newTeamName) {
          batch.update(player.reference, {'teamName': newTeamName});
        }
      }
    }

    batch
      ..update(teamRef, {
        ...fields,
        'lastCorrectionId': logRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(logRef, {
        'section': section.name,
        // nameLower follows name; the log lists what the FA changed
        'fields': [
          for (final field in fields.keys)
            if (field != 'nameLower') field,
        ],
        'lines': lines,
        'reason': reason.trim(),
        'nameKey': ?nameKey,
        'byUid': faUid,
        'byName': ?faName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.teamCorrected,
      teamId: teamId,
      teamName: newTeamName,
      name: '${lines.join('; ')} ("${reason.trim()}")',
    );
    await batch.commit().timeout(_timeout);
  }
}

final teamCorrectionRepositoryProvider =
    Provider<TeamCorrectionRepository>((ref) {
  return TeamCorrectionRepository(ref.watch(firestoreProvider));
});

/// A team's corrections log, newest first (FA and the team's admins).
final teamCorrectionsProvider =
    StreamProvider.family<List<TeamCorrection>, String>((ref, teamId) {
  return ref.watch(teamCorrectionRepositoryProvider).watch(teamId);
});
