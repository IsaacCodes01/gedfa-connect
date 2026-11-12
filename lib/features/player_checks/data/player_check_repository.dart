import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';
import 'package:gedfa_connect/features/player_checks/domain/player_check.dart';

const _timeout = Duration(seconds: 15);

/// The commissioner's face check (3.6b, MC2): one document per match,
/// one player per save.
///
/// Like ticking names off at the kitchen door: each tick is written as
/// it happens, so nothing is lost if the phone dies halfway.
class PlayerCheckRepository {
  PlayerCheckRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String fixtureId) =>
      _db.doc(FirestorePaths.playerCheck(fixtureId));

  /// The FA and the match's officials.
  Stream<MatchPlayerChecks> watch(String fixtureId) => _ref(fixtureId)
      .snapshots()
      .map((snap) => MatchPlayerChecks.fromMap(fixtureId, snap.data()));

  /// The commissioner records [result] for one player. A mismatch needs a
  /// [note] (the screen asks; the rules check), and tells the FA in the
  /// same batch (3.6c): both are saved, or neither.
  Future<void> record({
    required Fixture fixture,
    required CheckLine line,
    required CheckResult result,
    String? note,
    required String by,
    required String byName,
  }) {
    final batch = _db.batch()
      ..set(
        _ref(fixture.id),
        MatchPlayerChecks.entryWrite(
          fixtureId: fixture.id,
          playerId: line.playerId,
          teamId: line.teamId,
          result: result,
          note: note,
          by: by,
          byName: byName,
        ),
        SetOptions(merge: true),
      );
    if (result == CheckResult.mismatch) {
      NotificationWriter(_db).forFaInBatch(
        batch,
        kind: NotificationKind.playerMismatch,
        teamId: '',
        teamName: byName,
        targetId: fixture.id,
        name: mismatchNoteLine(fixture, line, note),
      );
    }
    return batch.commit().timeout(_timeout);
  }
}

/// The FA's note line (3.6c): "#9 Nana Agyei (Asebu Stars)", then the
/// match and what the commissioner saw.
String mismatchNoteLine(Fixture f, CheckLine line, String? note) {
  final team = line.teamId == f.home.id ? f.home.name : f.away.name;
  final number = line.number == null ? '' : '#${line.number} ';
  final why = note?.trim() ?? '';
  return '$number${line.name} ($team)${AppNotification.lineBreak}'
      '${appointmentLine(f)}${why.isEmpty ? '' : '. "$why"'}';
}

final playerCheckRepositoryProvider = Provider<PlayerCheckRepository>(
  (ref) => PlayerCheckRepository(ref.watch(firestoreProvider)),
);

/// One match's face check (FA and the match's officials).
final playerChecksProvider = StreamProvider.family<MatchPlayerChecks, String>(
  (ref, fixtureId) => ref.watch(playerCheckRepositoryProvider).watch(fixtureId),
);
