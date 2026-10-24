import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/team_name_key.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';

const _timeout = Duration(seconds: 15);
const _uploadTimeout = Duration(seconds: 60);

class TeamRequestRepository {
  TeamRequestRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _requestRef(String uid) =>
      _db.doc(FirestorePaths.teamRequest(uid));

  DocumentReference<Map<String, dynamic>> _nameRef(String key) =>
      _db.doc(FirestorePaths.teamName(key));

  Stream<TeamRequest?> watch(String uid) {
    return _requestRef(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return TeamRequest.fromMap(snapshot.id, data);
    });
  }

  /// Every team request in the district, live. FA admins only (rules).
  /// Sorting happens in the app, so Firestore needs no extra index.
  Stream<List<TeamRequest>> watchAll() {
    return _db.collection(FirestorePaths.teamRequests).snapshots().map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              TeamRequest.fromMap(doc.id, doc.data()),
          ],
        );
  }

  /// True if [teamName]'s reservation exists and belongs to [uid].
  /// The FA checks this before approving.
  Future<bool> holdsName(String teamName, {required String uid}) async {
    final snapshot =
        await _nameRef(teamNameKey(teamName)).get().timeout(_timeout);
    return snapshot.exists && snapshot.data()?['uid'] == uid;
  }

  // ---------- FA review (2.2) ----------

  /// FA approves [request]. In ONE batch (all or nothing):
  /// 1. the request becomes 'approved' and remembers its team ID,
  /// 2. the team is created from the request's details,
  /// 3. the club's account becomes the team's admin.
  /// The team ID is the reserved team-name key, e.g. 'gomoa-united-fc'.
  Future<String> approve(TeamRequest request, {required String faUid}) async {
    final teamId = teamNameKey(request.teamName);
    final details = request.toEditableMap();
    final teamName = details['teamName'] as String;

    final batch = _db.batch()
      ..update(_requestRef(request.uid), {
        'status': ApprovalStatus.approved.name,
        'teamId': teamId,
        'reviewedBy': faUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(_db.doc(FirestorePaths.team(teamId)), {
        'name': teamName,
        'nameLower': teamName.toLowerCase(),
        'nameKey': teamId,
        // Copied as they are from the request
        for (final key in const [
          'shortName',
          'town',
          'homeGround',
          'homeGroundDirections',
          'yearFounded',
          'email',
          'logoUrl',
          'categories',
          'kits',
          'officials',
        ])
          key: details[key],
        'adminUids': [request.uid],
        'requestUid': request.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(_db.doc(FirestorePaths.user(request.uid)), {
        'role': 'teamAdmin',
        'teamId': teamId,
        'createdBy': faUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    // The new team's bell: "Gomoa United FC approved"
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.teamApproved,
      teamId: teamId,
      teamName: teamName,
      name: teamName,
    );

    await batch.commit().timeout(_timeout);
    return teamId;
  }

  /// FA rejects a request with a reason the club will see.
  Future<void> reject(
    String uid, {
    required String reason,
    required String faUid,
  }) {
    return _requestRef(uid).update({
      'status': ApprovalStatus.rejected.name,
      'rejectionReason': reason.trim(),
      'reviewedBy': faUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }

  Future<bool> isNameAvailable(String teamName, {required String uid}) async {
    final snapshot =
        await _nameRef(teamNameKey(teamName)).get().timeout(_timeout);
    if (!snapshot.exists) return true;
    return snapshot.data()?['uid'] == uid;
  }

  Future<String> uploadLogo({
    required String uid,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref(StoragePaths.teamRequestLogo(uid));
    await ref
        .putData(bytes, SettableMetadata(contentType: contentType))
        .timeout(_uploadTimeout);
    return ref.getDownloadURL();
  }

  Map<String, dynamic> _buildData(TeamRequest request) {
    return {
      ...request.toEditableMap(),
      'teamNameLower': request.teamName.trim().toLowerCase(),
      'nameKey': teamNameKey(request.teamName),
      'agreedToRules': true,
      'status': ApprovalStatus.pending.name,
      'rejectionReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _reservation(String uid) => {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Future<void> create(TeamRequest request) async {
    final uid = request.uid;
    if (!await isNameAvailable(request.teamName, uid: uid)) {
      throw const TeamNameTakenException();
    }

    final key = teamNameKey(request.teamName);
    final batch = _db.batch()
      ..set(_requestRef(uid), {
        ..._buildData(request),
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_nameRef(key), _reservation(uid));
    // The FA's bell: "New team request: Afransi Stars"
    NotificationWriter(_db).forFaInBatch(
      batch,
      kind: NotificationKind.teamRequest,
      teamId: uid,
      teamName: request.teamName.trim(),
      name: request.teamName.trim(),
    );

    await batch.commit().timeout(_timeout);
  }

  Future<void> update(
    TeamRequest request, {
    required String previousNameKey,
  }) async {
    final uid = request.uid;
    final key = teamNameKey(request.teamName);
    final renamed = key != previousNameKey;

    if (renamed && !await isNameAvailable(request.teamName, uid: uid)) {
      throw const TeamNameTakenException();
    }

    final batch = _db.batch()..update(_requestRef(uid), _buildData(request));
    if (renamed) {
      batch
        ..delete(_nameRef(previousNameKey))
        ..set(_nameRef(key), _reservation(uid));
    }

    await batch.commit().timeout(_timeout);
  }
}

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final teamRequestRepositoryProvider = Provider<TeamRequestRepository>((ref) {
  return TeamRequestRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  );
});

final myTeamRequestProvider = StreamProvider<TeamRequest?>((ref) async* {
  final authUser = await ref.watch(authStateProvider.future);
  if (authUser == null) {
    yield null;
    return;
  }
  yield* ref.watch(teamRequestRepositoryProvider).watch(authUser.uid);
});

/// FA: every team request, live.
final allTeamRequestsProvider = StreamProvider<List<TeamRequest>>((ref) {
  return ref.watch(teamRequestRepositoryProvider).watchAll();
});

/// FA: how many requests are waiting (the gold number on the Teams tab).
final pendingTeamRequestCountProvider = Provider<int>((ref) {
  final requests = ref.watch(allTeamRequestsProvider).value ?? const [];
  return requests
      .where((request) => request.status == ApprovalStatus.pending)
      .length;
});

/// FA: one request by the requester's uid, live.
final teamRequestByUidProvider =
    StreamProvider.family<TeamRequest?, String>((ref, uid) {
  return ref.watch(teamRequestRepositoryProvider).watch(uid);
});

/// FA: does this request still hold its team-name reservation?
/// The key is a record, so the same uid + name reuses the same answer.
final requestHoldsNameProvider =
    FutureProvider.family<bool, ({String uid, String teamName})>((ref, key) {
  return ref
      .watch(teamRequestRepositoryProvider)
      .holdsName(key.teamName, uid: key.uid);
});
