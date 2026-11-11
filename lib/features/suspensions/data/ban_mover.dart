import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/players/domain/division_juveniles.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/suspensions/domain/player_suspension.dart';

const _timeout = Duration(seconds: 15);

/// 3.1e2: before the FA postpones or cancels a match, the players
/// suspended for it move to their club's next match (like moving a
/// booking in the diary when a dinner is called off: the guest still owes
/// the same number of dinners).
///
/// ONE batch of its own, run just before the postpone: the marks come off
/// the match, go on the next ones, and each suspension gets its new list.
/// (A batch counts all its writes against the rules' 1000-expression
/// limit, and a postpone is already near it.) If the postpone then fails,
/// pressing Postpone again finds nothing left to move.
class BanMover {
  BanMover(this._db);

  final FirebaseFirestore _db;

  /// Moves everyone suspended for [off]. Returns how many players moved.
  Future<int> moveOff(Fixture off) async {
    if (off.banned.values.every((ids) => ids.isEmpty)) return 0;
    final snap = await _db
        .collection(FirestorePaths.playerSuspensions)
        .where('fixtureIds', arrayContains: off.id)
        .get()
        .timeout(_timeout);
    final suspensions = [
      for (final doc in snap.docs)
        ?PlayerSuspension.fromMap(doc.id, doc.data()),
    ];

    final fixtures = <Fixture>[];
    for (final teamId in {for (final s in suspensions) s.teamId}) {
      final teamSnap = await _db
          .collection(FirestorePaths.fixtures)
          .where('teamIds', arrayContains: teamId)
          .get()
          .timeout(_timeout);
      fixtures.addAll([
        for (final doc in teamSnap.docs) ?Fixture.fromMap(doc.id, doc.data()),
      ]);
    }

    final moves = BanPlan.movesFor(off, suspensions, fixtures, DateTime.now());
    // The match's marks go (also any left by a lifted suspension)
    final batch = _db.batch()
      ..update(_db.doc(FirestorePaths.fixture(off.id)), {
        'banned': FieldValue.delete(),
      });
    // One write per match: match ID → team ID → players moving there
    final marks = <String, Map<String, List<String>>>{};
    for (final m in moves) {
      final s = m.suspension;
      batch.update(_db.collection(FirestorePaths.playerSuspensions).doc(s.id), {
        'fixtureIds': m.fixtureIds,
      });
      if (m.to case final to?) {
        marks
            .putIfAbsent(to.id, () => {})
            .putIfAbsent(s.teamId, () => [])
            .add(s.playerId);
      }
    }
    for (final MapEntry(key: fixtureId, value: teams) in marks.entries) {
      batch.update(_db.doc(FirestorePaths.fixture(fixtureId)), {
        for (final MapEntry(key: teamId, value: players) in teams.entries)
          FieldPath(['banned', teamId]): FieldValue.arrayUnion(players),
      });
    }
    await batch.commit().timeout(_timeout);
    return moves.length;
  }
}

/// 3.1e3 (Isaac, 11 Nov 2026): a suspended player can't play in ANY
/// competition until the ban is served. Keeps every match's `banned` marks
/// right for some clubs: the counted matches, and every other match the
/// player could be picked for until the last counted one. Also fills a
/// ban still short of matches from new ones. Run after every suspension,
/// lift, postpone, cancel, new date and new match.
///
/// Writes only what differs, 10 matches per batch (a batch counts all its
/// writes against the rules' 1000-expression limit).
class BanSync {
  BanSync(this._db);

  final FirebaseFirestore _db;

  Future<void> syncTeams(Iterable<String> ids) async {
    final teamIds = ids.where((id) => id.isNotEmpty).toSet();
    if (teamIds.isEmpty) return;

    // The clubs' suspensions this season ("in" takes 10 at most)
    final suspensions = <PlayerSuspension>[];
    final list = teamIds.toList();
    for (var i = 0; i < list.length; i += 10) {
      final snap = await _db
          .collection(FirestorePaths.playerSuspensions)
          .where('teamId', whereIn: list.skip(i).take(10).toList())
          .get()
          .timeout(_timeout);
      suspensions.addAll([
        for (final doc in snap.docs)
          if (PlayerSuspension.fromMap(doc.id, doc.data()) case final s?)
            if (s.season == Season.current) s,
      ]);
    }

    final fixtures = [
      for (final doc
          in (await _db
                  .collection(FirestorePaths.fixtures)
                  .where('season', isEqualTo: Season.current)
                  .get()
                  .timeout(_timeout))
              .docs)
        ?Fixture.fromMap(doc.id, doc.data()),
    ];

    // Where each suspended player could be picked
    final players = <String, BanPlayer>{};
    final named = <String, DivisionJuveniles>{};
    for (final s in suspensions) {
      if (s.isLifted || players.containsKey(s.playerId)) continue;
      final doc = await _db
          .doc(FirestorePaths.player(s.playerId))
          .get()
          .timeout(_timeout);
      final data = doc.data();
      if (data == null) continue;
      final p = Player.fromMap(doc.id, data);
      if (p.isJuvenile && !named.containsKey(p.teamId)) {
        final list = await _db
            .doc(FirestorePaths.squad(p.teamId, 'divisionJuveniles'))
            .get()
            .timeout(_timeout);
        named[p.teamId] = DivisionJuveniles.fromMap(list.data());
      }
      players[s.playerId] = BanPlayer.of(
        p,
        named: named[p.teamId]?.contains(p.id) ?? false,
      );
    }

    final plan = BanSyncPlan.of(
      teamIds: teamIds,
      suspensions: suspensions,
      players: players,
      fixtures: fixtures,
      now: DateTime.now(),
    );
    if (plan.isEmpty) return;

    final writes = <void Function(WriteBatch)>[
      for (final MapEntry(key: id, value: ids) in plan.lists.entries)
        (b) => b.update(
          _db.collection(FirestorePaths.playerSuspensions).doc(id),
          {'fixtureIds': ids},
        ),
      for (final MapEntry(key: fixtureId, value: teams) in plan.marks.entries)
        (b) => b.update(_db.doc(FirestorePaths.fixture(fixtureId)), {
          for (final MapEntry(key: team, value: players) in teams.entries)
            FieldPath(['banned', team]): players,
        }),
    ];
    for (var i = 0; i < writes.length; i += 10) {
      final batch = _db.batch();
      for (final write in writes.skip(i).take(10)) {
        write(batch);
      }
      await batch.commit().timeout(_timeout);
    }
  }

  /// [syncTeams] that never fails the action it follows: the app still
  /// locks the players on the sheet from the suspensions themselves.
  Future<void> trySync(Iterable<String> teamIds) async {
    try {
      await syncTeams(teamIds);
    } catch (error) {
      debugPrint('Suspension marks not synced: $error');
    }
  }
}
