import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';

const _timeout = Duration(seconds: 15);

/// An approved team with ALL its details (2.10a): ground, kits,
/// colours, officials… The team document has the same fields as the
/// registration it was made from, so we read it with [TeamRequest].
/// Only `name` is called `teamName` there.
typedef TeamDetails = TeamRequest;

/// What a team admin can change on the team profile without the FA
/// (2.10a, board P1 "Saves straight away").
enum TeamSection {
  details('home ground'), // town, home ground, directions
  colours('colours'),
  kits('kits'),
  officials('officials');

  const TeamSection(this.noun);

  /// For the FA's bell: "Golden Unity FC updated their kits"
  final String noun;

  static TeamSection? fromString(String? value) {
    for (final section in values) {
      if (section.name == value) return section;
    }
    return null;
  }
}

/// Reads a team's full details and saves the direct edits.
class TeamProfileRepository {
  TeamProfileRepository(this._db);

  final FirebaseFirestore _db;

  Stream<TeamDetails?> watch(String teamId) {
    return _db.doc(FirestorePaths.team(teamId)).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return TeamRequest.fromMap(
        data['requestUid'] as String? ?? '',
        {...data, 'teamName': data['name']},
      );
    });
  }

  /// Saves [changes] (only the fields of [section]) straight away, and
  /// tells the FA in the same batch: "Golden Unity FC updated their kits"
  /// (one note per team and day, like the others).
  Future<void> saveDirect({
    required String teamId,
    required String teamName,
    required TeamSection section,
    required Map<String, dynamic> changes,
  }) {
    final batch = _db.batch()
      ..update(_db.doc(FirestorePaths.team(teamId)), {
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    NotificationWriter(_db).forFaInBatch(
      batch,
      kind: NotificationKind.teamUpdated,
      teamId: teamId,
      teamName: teamName,
      name: section.noun,
    );
    return batch.commit().timeout(_timeout);
  }
}

final teamProfileRepositoryProvider = Provider<TeamProfileRepository>((ref) {
  return TeamProfileRepository(ref.watch(firestoreProvider));
});

/// FA: any approved team with all its details, as it is now (2.11a).
final teamDetailsProvider =
    StreamProvider.family<TeamDetails?, String>((ref, teamId) {
  return ref.watch(teamProfileRepositoryProvider).watch(teamId);
});

/// The signed-in team admin's team, with all its details.
final myTeamDetailsProvider = StreamProvider<TeamDetails?>((ref) async* {
  final appUser = await ref.watch(appUserProvider.future);
  final teamId = appUser?.teamId;
  if (teamId == null || teamId.isEmpty) {
    yield null;
    return;
  }
  yield* ref.watch(teamProfileRepositoryProvider).watch(teamId);
});
