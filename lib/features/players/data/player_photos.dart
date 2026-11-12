import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';

/// Player photos for the face check (3.6a): `playerPhotos/{playerId}` holds
/// an APPROVED player's registered photo links, copied by the FA in the
/// same write as the approval (or by Repair).
///
/// Why: on match day the commissioner checks each face against the
/// registered photo (3.6). Only the team and the FA can read player files,
/// and the club must not be able to swap a photo, so the FA keeps this
/// copy. The rules allow only the player's own links (Isaac, 12 Nov 2026:
/// the FA and every referee may read it).

/// `playerPhotos/{playerId}`.
DocumentReference<Map<String, dynamic>> playerPhotoRef(
  FirebaseFirestore db,
  String playerId,
) => db.doc(FirestorePaths.playerPhoto(playerId));

/// The copy of a player's photo links, from the player's data, or null
/// when a link is missing (nothing to copy).
Map<String, dynamic>? playerPhotoCopy(Map<String, dynamic> player) {
  final teamId = player['teamId'], photo = player['photoUrl'];
  final thumb = player['thumbUrl'];
  if (teamId is! String || photo is! String || thumb is! String) return null;
  if (photo.isEmpty || thumb.isEmpty) return null;
  return {
    'teamId': teamId,
    'photoUrl': photo,
    'thumbUrl': thumb,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// Is the copy in [snapshot] the same as the player's links in [player]?
bool isPhotoCopyUpToDate(
  DocumentSnapshot<Map<String, dynamic>>? snapshot,
  Map<String, dynamic> player,
) {
  final data = snapshot?.data();
  return data != null &&
      data['teamId'] == player['teamId'] &&
      data['photoUrl'] == player['photoUrl'] &&
      data['thumbUrl'] == player['thumbUrl'];
}

/// One player's registered photo, as the commissioner sees it (3.6).
class PlayerPhoto {
  const PlayerPhoto({
    required this.playerId,
    required this.teamId,
    required this.photoUrl,
    required this.thumbUrl,
  });

  final String playerId;
  final String teamId;
  final String photoUrl;
  final String thumbUrl;

  static PlayerPhoto? fromMap(String id, Map<String, dynamic>? data) {
    final teamId = data?['teamId'], photo = data?['photoUrl'];
    final thumb = data?['thumbUrl'];
    if (teamId is! String || photo is! String || thumb is! String) {
      return null;
    }
    return PlayerPhoto(
      playerId: id,
      teamId: teamId,
      photoUrl: photo,
      thumbUrl: thumb,
    );
  }
}

/// One player's registered photo (FA and referees only), or null.
final playerPhotoProvider = FutureProvider.autoDispose
    .family<PlayerPhoto?, String>((ref, playerId) async {
      final snap = await playerPhotoRef(
        ref.watch(firestoreProvider),
        playerId,
      ).get();
      return PlayerPhoto.fromMap(snap.id, snap.data());
    });
