import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/players/domain/division_juveniles.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

const _timeout = Duration(seconds: 15);

/// The squad-list group of a club's juveniles in the Division (3.1d).
const divisionJuvenilesGroup = 'divisionJuveniles';

/// Juveniles in the Division (3.1d1): `squads/{teamId}_divisionJuveniles`,
/// `players` = player ID → age group ("U15"). The team names or removes
/// one player per write; the FA is told in the bell ("… updated their
/// juveniles in the Division"), in the same batch.
class DivisionJuvenilesRepository {
  DivisionJuvenilesRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String teamId) =>
      _db.doc(FirestorePaths.squad(teamId, divisionJuvenilesGroup));

  Stream<DivisionJuveniles> watch(String teamId) => _ref(
    teamId,
  ).snapshots().map((snap) => DivisionJuveniles.fromMap(snap.data()));

  /// Names [player]. [current] is checked first so the team is told why
  /// not; the rules check the same.
  Future<void> add({
    required Team team,
    required Player player,
    required DivisionJuveniles current,
  }) {
    final why = current.whyNot(player);
    if (why != null) throw DivisionJuvenileException(why);
    final batch = _db.batch()
      ..set(_ref(team.id), {
        'teamId': team.id,
        'group': divisionJuvenilesGroup,
        'players': {player.id: player.ageGroup!.label},
        'changed': player.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    _tellFa(batch, team);
    return batch.commit().timeout(_timeout);
  }

  Future<void> remove({required Team team, required String playerId}) {
    final batch = _db.batch()
      ..update(_ref(team.id), {
        'players.$playerId': FieldValue.delete(),
        'changed': playerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    _tellFa(batch, team);
    return batch.commit().timeout(_timeout);
  }

  void _tellFa(WriteBatch batch, Team team) =>
      NotificationWriter(_db).forFaInBatch(
        batch,
        kind: NotificationKind.teamUpdated,
        teamId: team.id,
        teamName: team.name,
        name: 'juveniles in the Division',
      );
}

/// Why a juvenile can't be named (shown as a toast).
class DivisionJuvenileException implements Exception {
  const DivisionJuvenileException(this.message);

  final String message;

  @override
  String toString() => message;
}

final divisionJuvenilesRepositoryProvider =
    Provider<DivisionJuvenilesRepository>(
      (ref) => DivisionJuvenilesRepository(ref.watch(firestoreProvider)),
    );

/// My club's juveniles in the Division, live.
final myDivisionJuvenilesProvider = StreamProvider<DivisionJuveniles>((
  ref,
) async* {
  final team = await ref.watch(myTeamProvider.future);
  if (team == null || !team.hasBoth) {
    yield const DivisionJuveniles();
    return;
  }
  yield* ref.watch(divisionJuvenilesRepositoryProvider).watch(team.id);
});
