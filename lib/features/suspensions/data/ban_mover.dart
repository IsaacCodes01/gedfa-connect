import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
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
