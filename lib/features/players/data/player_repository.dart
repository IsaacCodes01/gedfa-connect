import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/passport_photo.dart';
import 'package:gedfa_connect/core/utils/player_key.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart'
    show firebaseStorageProvider;

const _timeout = Duration(seconds: 15);
const _uploadTimeout = Duration(seconds: 60);

/// The important things that changed, in plain words.
/// Empty list = nothing that needs the FA again.
List<String> reapprovalChanges(
  Player before,
  Player after, {
  bool photoChanged = false,
}) {
  String clean(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  return [
    if (clean(before.fullName) != clean(after.fullName)) 'name',
    if (before.dob != after.dob) 'date of birth',
    if (before.jerseyNo != after.jerseyNo) 'jersey number',
    if (photoChanged) 'photo',
  ];
}

/// True if a change to an approved player must go back to the FA.
bool needsReapproval(
  Player before,
  Player after, {
  bool photoChanged = false,
}) =>
    reapprovalChanges(before, after, photoChanged: photoChanged).isNotEmpty;

class PlayerRepository {
  PlayerRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _players =>
      _db.collection(FirestorePaths.players);

  /// `teams/{teamId}/jerseys/{category-number}` for this player.
  DocumentReference<Map<String, dynamic>> _jerseyRef(Player player) =>
      _db.doc(FirestorePaths.jersey(
        player.teamId,
        jerseyIdFor(player.category.name, player.jerseyNo),
      ));

  /// `playerKeys/{name_dob}` for this player.
  DocumentReference<Map<String, dynamic>> _keyRef(Player player) =>
      _db.doc(FirestorePaths.playerKey(player.playerKey));

  // ---------- Reading ----------

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

  // ---------- Photos ----------

  /// Uploads the photo and thumbnail with a fresh file name each time
  /// (photo-<time>.jpg), so a new photo always gets a new link.
  Future<({String photoUrl, String thumbUrl})> _uploadPhoto({
    required String teamId,
    required String playerId,
    required ProcessedPhoto photo,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final photoRef = _storage
        .ref(StoragePaths.playerFile(teamId, playerId, 'photo-$stamp.jpg'));
    final thumbRef = _storage
        .ref(StoragePaths.playerFile(teamId, playerId, 'thumb-$stamp.jpg'));
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    await Future.wait([
      photoRef.putData(photo.full, metadata),
      thumbRef.putData(photo.thumb, metadata),
    ]).timeout(_uploadTimeout);

    return (
      photoUrl: await photoRef.getDownloadURL(),
      thumbUrl: await thumbRef.getDownloadURL(),
    );
  }

  /// Deletes old photo files. Best effort: a leftover file is harmless.
  Future<void> _deleteFiles(List<String?> urls) async {
    for (final url in urls) {
      if (url == null || url.isEmpty) continue;
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // Already gone, or not ours to delete. Ignore.
      }
    }
  }

  // ---------- Checks ----------

  /// Throws a friendly error if the number or the person is already taken
  /// by someone other than [exceptPlayerId].
  Future<void> _checkFree(
    Player player, {
    String? exceptPlayerId,
    bool checkJersey = true,
    bool checkKey = true,
  }) async {
    if (checkJersey) {
      final jersey = await _jerseyRef(player).get().timeout(_timeout);
      if (jersey.exists && jersey.data()?['playerId'] != exceptPlayerId) {
        throw JerseyTakenException(player.jerseyNo);
      }
    }
    if (checkKey) {
      final key = await _keyRef(player).get().timeout(_timeout);
      if (key.exists && key.data()?['playerId'] != exceptPlayerId) {
        throw DuplicatePlayerException(
          sameTeam: key.data()?['teamId'] == player.teamId,
        );
      }
    }
  }

  /// Commits a batch. If the server refuses it, checks again whether
  /// someone took the number or the player meanwhile, to show a clear
  /// message instead of "not allowed".
  Future<void> _commit(
    WriteBatch batch,
    Future<void> Function() recheck,
  ) async {
    try {
      await batch.commit().timeout(_timeout);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') await recheck();
      rethrow;
    }
  }

  // ---------- Writing ----------

  /// Adds a new player as Pending: uploads the photo, then saves the
  /// player with their jersey and player-key reservations (all or none).
  /// Returns the new document ID.
  Future<String> create(Player player, {required ProcessedPhoto photo}) async {
    await _checkFree(player);

    final ref = _players.doc(); // Firestore makes the ID now
    final urls = await _uploadPhoto(
      teamId: player.teamId,
      playerId: ref.id,
      photo: photo,
    );

    final batch = _db.batch()
      ..set(ref, {
        ...player.toEditableMap(),
        'photoUrl': urls.photoUrl,
        'thumbUrl': urls.thumbUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(_jerseyRef(player), {
        'playerId': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_keyRef(player), {
        'playerId': ref.id,
        'teamId': player.teamId,
        'createdAt': FieldValue.serverTimestamp(),
      });

    try {
      await _commit(batch, () => _checkFree(player));
    } catch (_) {
      // The player wasn't saved, so remove the photo we just uploaded
      await _deleteFiles([urls.photoUrl, urls.thumbUrl]);
      rethrow;
    }
    return ref.id;
  }

  /// Saves changes. Uploads [newPhoto] if given. Moves the jersey and
  /// player-key reservations if the number, name or date of birth changed.
  /// An approved player stays approved only if nothing important changed.
  Future<void> update(
    Player before,
    Player after, {
    ProcessedPhoto? newPhoto,
  }) async {
    final photoChanged = newPhoto != null;
    final jerseyChanged = before.jerseyNo != after.jerseyNo;
    final keyChanged = before.playerKey != after.playerKey;
    final keepApproved = before.isApproved &&
        !needsReapproval(before, after, photoChanged: photoChanged);

    Future<void> check() => _checkFree(
          after,
          exceptPlayerId: before.id,
          checkJersey: jerseyChanged,
          checkKey: keyChanged,
        );
    await check();

    final urls = newPhoto == null
        ? null
        : await _uploadPhoto(
            teamId: before.teamId,
            playerId: before.id,
            photo: newPhoto,
          );

    final batch = _db.batch()
      ..update(_db.doc(FirestorePaths.player(before.id)), {
        ...after.toEditableMap(),
        if (urls != null) 'photoUrl': urls.photoUrl,
        if (urls != null) 'thumbUrl': urls.thumbUrl,
        'status': keepApproved ? 'approved' : 'pending',
        if (!keepApproved) 'rejectionReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

    if (jerseyChanged) {
      batch
        ..delete(_jerseyRef(before))
        ..set(_jerseyRef(after), {
          'playerId': before.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
    }
    if (keyChanged) {
      batch
        ..delete(_keyRef(before))
        ..set(_keyRef(after), {
          'playerId': before.id,
          'teamId': after.teamId,
          'createdAt': FieldValue.serverTimestamp(),
        });
    }

    try {
      await _commit(batch, check);
    } catch (_) {
      if (urls != null) await _deleteFiles([urls.photoUrl, urls.thumbUrl]);
      rethrow;
    }

    // Saved: the old photo files are no longer used
    if (urls != null) await _deleteFiles([before.photoUrl, before.thumbUrl]);
  }
}

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  );
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
