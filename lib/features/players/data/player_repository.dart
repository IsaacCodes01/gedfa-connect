import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';

const _timeout = Duration(seconds: 15);

/// The important things that changed, in plain words.
/// Empty list = nothing that needs the FA again.
List<String> reapprovalChanges(Player before, Player after) {
  String clean(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  return [
    if (clean(before.fullName) != clean(after.fullName)) 'name',
    if (before.dob != after.dob) 'date of birth',
    if (before.jerseyNo != after.jerseyNo) 'jersey number',
    if (before.photoUrl != after.photoUrl) 'photo',
  ];
}

/// True if a change to an approved player must go back to the FA.
bool needsReapproval(Player before, Player after) =>
    reapprovalChanges(before, after).isNotEmpty;

class PlayerRepository {
  PlayerRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _players =>
      _db.collection(FirestorePaths.players);

  /// All players of one team, live, sorted by jersey number.
  /// Sorting happens in the app, so Firestore needs no extra index.
  Stream<List<Player>> watchTeam(String teamId) {
    return _players
        .where('teamId', isEqualTo: teamId)
        .snapshots()
        .map((snapshot) {
      final players = [
        for (final doc in snapshot.docs) Player.fromMap(doc.id, doc.data()),
      ];
      players.sort((a, b) => a.jerseyNo.compareTo(b.jerseyNo));
      return players;
    });
  }

  /// One player, live. Gives null if it was deleted.
  Stream<Player?> watch(String playerId) {
    return _db.doc(FirestorePaths.player(playerId)).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return null;
        return Player.fromMap(snapshot.id, data);
      },
    );
  }

  /// Adds a new player as Pending. Returns the new document ID.
  Future<String> create(Player player) async {
    final ref = _players.doc(); // Firestore makes the ID
    await ref.set({
      ...player.toEditableMap(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
    return ref.id;
  }

  /// Saves changes. An approved player stays approved only if
  /// nothing important changed (see [needsReapproval]).
  Future<void> update(Player before, Player after) {
    final keepApproved = before.isApproved && !needsReapproval(before, after);

    return _db.doc(FirestorePaths.player(before.id)).update({
      ...after.toEditableMap(),
      'status': keepApproved ? 'approved' : 'pending',
      if (!keepApproved) 'rejectionReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }
}

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref.watch(firestoreProvider));
});

/// Every player of my team (both competitions). Screens filter by
/// competition, position and search in the app.
final teamPlayersProvider = StreamProvider<List<Player>>((ref) async* {
  final team = await ref.watch(myTeamProvider.future);
  if (team == null) {
    yield const [];
    return;
  }
  yield* ref.watch(playerRepositoryProvider).watchTeam(team.id);
});

/// One player by ID, for the Player details screen.
final playerProvider =
    StreamProvider.family<Player?, String>((ref, playerId) {
  return ref.watch(playerRepositoryProvider).watch(playerId);
});