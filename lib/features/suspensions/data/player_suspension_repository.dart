import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/suspensions/data/ban_mover.dart';
import 'package:gedfa_connect/features/suspensions/domain/player_suspension.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';

const _timeout = Duration(seconds: 15);

/// The FA suspends a player for a number of matches, or lifts it (3.1e1).
///
/// Like the referee's book: the page itself (`playerSuspensions/{id}`), a
/// mark on each match the player misses (`fixtures/{id}.banned`, team ID →
/// player IDs) and the note in the club's bell are written in ONE batch,
/// so they can never disagree.
class PlayerSuspensionRepository {
  PlayerSuspensionRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _all =>
      _db.collection(FirestorePaths.playerSuspensions);

  List<PlayerSuspension> _read(QuerySnapshot<Map<String, dynamic>> snap) => [
    for (final doc in snap.docs) ?PlayerSuspension.fromMap(doc.id, doc.data()),
  ];

  /// FA: every suspension of [season].
  Stream<List<PlayerSuspension>> watchSeason(String season) =>
      _all.where('season', isEqualTo: season).snapshots().map(_read);

  /// A club's suspensions of [season] (filtered in the app: no index).
  Stream<List<PlayerSuspension>> watchTeam(String teamId, String season) => _all
      .where('teamId', isEqualTo: teamId)
      .snapshots()
      .map((s) => _read(s).where((b) => b.season == season).toList());

  /// [toMiss]: the matches the FA saw on the form (BanPlan.matchesToMiss).
  /// [back]: the return match, for the club's note.
  Future<void> suspend({
    required Player player,
    required BanCompetition competition,
    required BanReason reason,
    String? reasonText,
    String? note,
    required int matches,
    required List<Fixture> toMiss,
    required Fixture? back,
    required String byUid,
    String? byName,
  }) async {
    final ref = _all.doc();
    final other = reasonText?.trim() ?? '';
    final noteText = note?.trim() ?? '';
    final batch = _db.batch()
      ..set(ref, {
        'playerId': player.id,
        'playerName': player.fullName,
        'playerCode': player.playerCode,
        'teamId': player.teamId,
        'teamName': player.teamName,
        'season': Season.current,
        'category': competition.category.name,
        'group': competition.group,
        'reason': reason.name,
        if (reason == BanReason.other) 'reasonText': other,
        if (noteText.isNotEmpty) 'note': noteText,
        'matches': matches,
        'fixtureIds': [for (final f in toMiss) f.id],
        'byUid': byUid,
        'byName': ?byName,
        'at': FieldValue.serverTimestamp(),
      });
    for (final f in toMiss) {
      batch.update(_db.doc(FirestorePaths.fixture(f.id)), {
        FieldPath(['banned', player.teamId]): FieldValue.arrayUnion([
          player.id,
        ]),
      });
    }
    final reasonLabel = reason == BanReason.other ? other : reason.label;
    final notInCalendar = matches - toMiss.length;
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.playerSuspended,
      teamId: player.teamId,
      teamName: player.teamName,
      targetId: player.id,
      name:
          '${_name(player, competition)} suspended for '
          '${matches == 1 ? '1 match' : '$matches matches'}'
          '${AppNotification.lineBreak}$reasonLabel. '
          '${BanPlan.missesText(toMiss, teamId: player.teamId, notInCalendar: notInCalendar)} '
          'No other match until then. '
          '${BanPlan.returnsText(back, teamId: player.teamId, pending: notInCalendar)}',
    );
    await batch.commit().timeout(_timeout);
    // Blocked from every other competition until then too (3.1e3)
    await BanSync(_db).trySync([player.teamId]);
  }

  /// Ends [s] early, with why. The player's marks come off the matches
  /// they had still to miss, in the same batch.
  Future<void> lift(
    PlayerSuspension s, {
    required BanLiftReason reason,
    String? note,
    required String byUid,
    String? byName,
  }) async {
    final text = note?.trim() ?? '';
    final batch = _db.batch()
      ..update(_all.doc(s.id), {
        'liftedAt': FieldValue.serverTimestamp(),
        'liftReason': reason.name,
        if (text.isNotEmpty) 'liftNote': text,
        'liftedByUid': byUid,
        'liftedByName': ?byName,
      });
    for (final id in s.fixtureIds) {
      batch.update(_db.doc(FirestorePaths.fixture(id)), {
        FieldPath(['banned', s.teamId]): FieldValue.arrayRemove([s.playerId]),
      });
    }
    final why = reason == BanLiftReason.other ? text : reason.label;
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.playerSuspensionLifted,
      teamId: s.teamId,
      teamName: s.teamName,
      targetId: s.playerId,
      name:
          '${s.displayName}${AppNotification.lineBreak}$why. '
          '${s.playerName} can be picked again.',
    );
    await batch.commit().timeout(_timeout);
    // Free in every competition again (3.1e3)
    await BanSync(_db).trySync([s.teamId]);
  }

  static String _name(Player p, BanCompetition c) =>
      c.ageGroup == null ? p.fullName : '${p.fullName} (${c.label})';
}

final playerSuspensionRepositoryProvider = Provider<PlayerSuspensionRepository>(
  (ref) {
    return PlayerSuspensionRepository(ref.watch(firestoreProvider));
  },
);

/// FA: every player suspension of the live season.
final seasonSuspensionsProvider = StreamProvider<List<PlayerSuspension>>((ref) {
  return ref
      .watch(playerSuspensionRepositoryProvider)
      .watchSeason(Season.current);
});

/// The signed-in team admin's player suspensions this season.
final mySuspensionsProvider = StreamProvider<List<PlayerSuspension>>((
  ref,
) async* {
  final team = await ref.watch(myTeamProvider.future);
  if (team == null) {
    yield const [];
    return;
  }
  yield* ref
      .watch(playerSuspensionRepositoryProvider)
      .watchTeam(team.id, Season.current);
});

/// FA: the suspensions in force, by player ID, worked out from the
/// season's matches (a player has at most one in force).
final faBansProvider = Provider<Map<String, BanStatus>>((ref) {
  final all = ref.watch(seasonSuspensionsProvider).value ?? const [];
  final fixtures = ref.watch(seasonFixturesProvider).value ?? const [];
  return bansByPlayer(all, fixtures, DateTime.now());
});

/// The club: its suspensions in force, by player ID.
final myBansProvider = Provider<Map<String, BanStatus>>((ref) {
  final all = ref.watch(mySuspensionsProvider).value ?? const [];
  final fixtures = ref.watch(myFixturesProvider).value ?? const [];
  return bansByPlayer(all, fixtures, DateTime.now());
});

/// Player ID → the suspension in force (the newest, if ever two).
Map<String, BanStatus> bansByPlayer(
  List<PlayerSuspension> all,
  List<Fixture> fixtures,
  DateTime now,
) {
  final sorted = [
    ...all,
  ]..sort((a, b) => (a.at ?? DateTime(2000)).compareTo(b.at ?? DateTime(2000)));
  return {for (final s in sorted) s.playerId: ?BanStatus.of(s, fixtures, now)};
}
