import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

class TeamRepository {
  TeamRepository(this._db);

  final FirebaseFirestore _db;

  /// Follows one team live. Gives null if the document doesn't exist.
  Stream<Team?> watch(String teamId) {
    return _db.doc(FirestorePaths.team(teamId)).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return Team.fromMap(snapshot.id, data);
    });
  }
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(firestoreProvider));
});

/// The team the signed-in team admin manages (from `users/{uid}.teamId`).
final myTeamProvider = StreamProvider<Team?>((ref) async* {
  final appUser = await ref.watch(appUserProvider.future);
  final teamId = appUser?.teamId;

  if (teamId == null || teamId.isEmpty) {
    yield null;
    return;
  }
  yield* ref.watch(teamRepositoryProvider).watch(teamId);
});
