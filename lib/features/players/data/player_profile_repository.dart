import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/players/domain/player_profile.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';

const _timeout = Duration(seconds: 15);

/// Player profiles and armbands (2.3d). The team saves these directly:
/// no FA approval, and the player's registration is never touched.
class PlayerProfileRepository {
  PlayerProfileRepository(this._db);

  final FirebaseFirestore _db;

  /// Every profile of one team, live, by player ID. Players without a
  /// profile are simply missing (the screens use an empty one).
  Stream<Map<String, PlayerProfile>> watchTeam(String teamId) {
    return _db
        .collection(FirestorePaths.playerProfiles)
        .where('teamId', isEqualTo: teamId)
        .snapshots()
        .map((snapshot) => {
              for (final doc in snapshot.docs)
                doc.id: PlayerProfile.fromMap(doc.id, doc.data()),
            });
  }

  /// Captain and vice-captain of one squad, live.
  Stream<Armbands> watchArmbands(String teamId, String category) {
    return _db
        .doc(FirestorePaths.armbands(teamId, category))
        .snapshots()
        .map((snapshot) => Armbands.fromMap(snapshot.data()));
  }

  /// Saves the profile and, if it changed, the armband, in one batch.
  ///
  /// [before] is the profile as it was (an empty one if new), so we know
  /// whether the availability changed (then its date is renewed).
  Future<void> save({
    required PlayerProfile before,
    required PlayerProfile after,
    required String category,
    required Armbands armbands,
    required Armband armband,
  }) async {
    final id = after.playerId;
    String? clean(String? text) {
      final value = text?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final availabilityChanged =
        before.availability != after.availability || before.availabilityAt == null;

    final batch = _db.batch()
      ..set(_db.doc(FirestorePaths.playerProfile(id)), {
        'teamId': after.teamId,
        'heightCm': after.heightCm,
        'weightKg': after.weightKg,
        'foot': after.foot?.name,
        'otherPositions': [for (final p in after.otherPositions) p.code],
        'strengths': [for (final s in after.strengths) s.name],
        'hometown': clean(after.hometown),
        'clubSince': after.clubSince,
        'previousClub': clean(after.previousClub),
        'availability': after.availability.name,
        // An expected date only makes sense while away
        'expectedBack': after.isAvailable || after.expectedBack == null
            ? null
            : Timestamp.fromDate(after.expectedBack!),
        'availabilityAt': availabilityChanged
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(before.availabilityAt!),
        'emergencyName': clean(after.emergencyName),
        'emergencyPhone': clean(after.emergencyPhone),
        'updatedAt': FieldValue.serverTimestamp(),
      });

    // Work out the new armbands. Giving the captaincy to someone moves it
    // (the old captain loses it); a player can't hold both.
    var captain = armbands.captainId;
    var vice = armbands.viceCaptainId;
    switch (armband) {
      case Armband.captain:
        captain = id;
        if (vice == id) vice = null;
      case Armband.viceCaptain:
        vice = id;
        if (captain == id) captain = null;
      case Armband.none:
        if (captain == id) captain = null;
        if (vice == id) vice = null;
    }
    if (captain != armbands.captainId || vice != armbands.viceCaptainId) {
      batch.set(_db.doc(FirestorePaths.armbands(after.teamId, category)), {
        'captainId': captain,
        'viceCaptainId': vice,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit().timeout(_timeout);
  }
}

final playerProfileRepositoryProvider =
    Provider<PlayerProfileRepository>((ref) {
  return PlayerProfileRepository(ref.watch(firestoreProvider));
});

/// My team's profiles, by player ID.
final teamProfilesProvider =
    StreamProvider<Map<String, PlayerProfile>>((ref) async* {
  final team = await ref.watch(myTeamProvider.future);
  if (team == null) {
    yield const {};
    return;
  }
  yield* ref.watch(playerProfileRepositoryProvider).watchTeam(team.id);
});

/// My team's captain and vice-captain for one competition
/// ('division' or 'juvenile').
final armbandsProvider =
    StreamProvider.family<Armbands, String>((ref, category) async* {
  final team = await ref.watch(myTeamProvider.future);
  if (team == null) {
    yield const Armbands();
    return;
  }
  yield* ref
      .watch(playerProfileRepositoryProvider)
      .watchArmbands(team.id, category);
});
