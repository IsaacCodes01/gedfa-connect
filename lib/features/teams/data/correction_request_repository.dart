import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/teams/domain/correction_request.dart';

const _timeout = Duration(seconds: 15);

/// The FA asks a team to correct something itself (2.11b).
///
/// Like a note pinned to the team's kitchen door: "please fix the head
/// coach's number". The team fixes it in its own app and takes the note
/// back to the FA ("Send back to the FA"); the FA checks and files it
/// (Done) or pins a new one (Ask again). Each step and its bell note are
/// ONE batch.
class CorrectionRequestRepository {
  CorrectionRequestRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String teamId) =>
      _db.doc(FirestorePaths.correctionRequest(teamId));

  /// One team's request (or null), live.
  Stream<CorrectionRequest?> watch(String teamId) =>
      _ref(teamId).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : CorrectionRequest.fromMap(doc.id, data);
      });

  /// FA: every team's request, live.
  Stream<List<CorrectionRequest>> watchAll() => _db
      .collection(FirestorePaths.correctionRequests)
      .snapshots()
      .map((snapshot) => [
            for (final doc in snapshot.docs)
              CorrectionRequest.fromMap(doc.id, doc.data()),
          ]);

  /// FA: asks (or asks again, [round] + 1) and tells the team.
  Future<void> ask({
    required String teamId,
    required String teamName,
    required Set<CorrectionItem> items,
    required String message,
    required int round,
    required String faUid,
    String? faName,
  }) {
    final itemNames = [
      for (final item in CorrectionItem.values)
        if (items.contains(item)) item.name,
    ];
    final batch = _db.batch()
      // set (not merge): the last round's send-back and done go away
      ..set(_ref(teamId), {
        'teamId': teamId,
        'teamName': teamName,
        'items': itemNames,
        'message': message.trim(),
        'status': CorrectionStatus.asked.name,
        'askedBy': faUid,
        'askedByName': ?faName,
        'askedAt': FieldValue.serverTimestamp(),
        'round': round,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.correctionAsked,
      teamId: teamId,
      teamName: teamName,
      name: [
        for (final item in CorrectionItem.values)
          if (items.contains(item)) item.shortLabel,
      ].join(', '),
    );
    return batch.commit().timeout(_timeout);
  }

  /// The team: "Send back to the FA", and tells the FA.
  Future<void> sendBack(CorrectionRequest request, {required String uid}) {
    final batch = _db.batch()
      ..update(_ref(request.teamId), {
        'status': CorrectionStatus.sentBack.name,
        'sentBackBy': uid,
        'sentBackAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    NotificationWriter(_db).forFaInBatch(
      batch,
      kind: NotificationKind.correctionSentBack,
      teamId: request.teamId,
      teamName: request.teamName,
      name: request.itemsText,
    );
    return batch.commit().timeout(_timeout);
  }

  /// FA: the team's fix looks good. Tells the team.
  Future<void> markDone(CorrectionRequest request, {required String faUid}) {
    final batch = _db.batch()
      ..update(_ref(request.teamId), {
        'status': CorrectionStatus.done.name,
        'doneBy': faUid,
        'doneAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.correctionDone,
      teamId: request.teamId,
      teamName: request.teamName,
      name: request.itemsText,
    );
    return batch.commit().timeout(_timeout);
  }
}

final correctionRequestRepositoryProvider =
    Provider<CorrectionRequestRepository>((ref) {
  return CorrectionRequestRepository(ref.watch(firestoreProvider));
});

/// One team's request (FA, or the team itself), live.
final correctionRequestProvider =
    StreamProvider.family<CorrectionRequest?, String>((ref, teamId) {
  return ref.watch(correctionRequestRepositoryProvider).watch(teamId);
});

/// The signed-in team admin's request (the yellow banner, B3).
final myCorrectionRequestProvider =
    StreamProvider<CorrectionRequest?>((ref) async* {
  final appUser = await ref.watch(appUserProvider.future);
  final teamId = appUser?.teamId;
  if (teamId == null || teamId.isEmpty) {
    yield null;
    return;
  }
  yield* ref.watch(correctionRequestRepositoryProvider).watch(teamId);
});

/// FA: every team's request, live.
final allCorrectionRequestsProvider =
    StreamProvider<List<CorrectionRequest>>((ref) {
  return ref.watch(correctionRequestRepositoryProvider).watchAll();
});

/// FA: how many teams sent a correction back (waiting for the FA).
final sentBackCorrectionCountProvider = Provider<int>((ref) {
  final requests = ref.watch(allCorrectionRequestsProvider).value ?? const [];
  return requests.where((r) => r.status == CorrectionStatus.sentBack).length;
});
