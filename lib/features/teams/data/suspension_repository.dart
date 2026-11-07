import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/teams/domain/suspension.dart';

const _timeout = Duration(seconds: 15);

/// The chairman suspends a team, or lifts its suspension (2.11c).
///
/// Like a red card for the club: the referee (the chairman) shows it,
/// writes it in the match book (the team's history) and the club is told,
/// all at once. A dated card runs out by itself; lifting it early is
/// written in the same book with why (fine paid, bond signed…).
class SuspensionRepository {
  SuspensionRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _history(String teamId) =>
      _db.collection(FirestorePaths.teamSuspensions(teamId));

  /// A team's suspensions, newest first, live.
  Stream<List<Suspension>> watchHistory(String teamId) => _history(teamId)
      .orderBy('since', descending: true)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            ?Suspension.fromMap(doc.id, doc.data()),
        ],
      );

  /// [lastDay]: the last day of a dated suspension, or null until the
  /// chairman lifts it.
  Future<void> suspend({
    required String teamId,
    required String teamName,
    required String reason,
    required DateTime? lastDay,
    required String chairUid,
    String? chairName,
  }) {
    final line = _history(teamId).doc();
    final details = {
      'reason': reason.trim(),
      'since': FieldValue.serverTimestamp(),
      'until': lastDay == null
          ? null
          : Timestamp.fromDate(Suspension.endOf(lastDay)),
      'byUid': chairUid,
      'byName': ?chairName,
    };
    final batch = _db.batch()
      ..update(_db.doc(FirestorePaths.team(teamId)), {
        'suspension': {'id': line.id, ...details},
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(line, details);
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.teamSuspended,
      teamId: teamId,
      teamName: teamName,
      name: lastDay == null
          ? reason.trim()
          : '${reason.trim()} (until ${formatDayMonth(lastDay)})',
    );
    return batch.commit().timeout(_timeout);
  }

  /// Lifts [suspension] (also one whose date has passed), with why.
  Future<void> lift({
    required String teamId,
    required String teamName,
    required Suspension suspension,
    required LiftReason reason,
    required String? note,
    required String chairUid,
    String? chairName,
  }) {
    final text = note?.trim();
    final hasNote = text != null && text.isNotEmpty;
    final batch = _db.batch()
      ..update(_db.doc(FirestorePaths.team(teamId)), {
        'suspension': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..update(_history(teamId).doc(suspension.id), {
        'liftedAt': FieldValue.serverTimestamp(),
        'liftedBy': chairUid,
        'liftReason': reason.name,
        if (hasNote) 'liftNote': text,
        'liftedByName': ?chairName,
      });
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.suspensionLifted,
      teamId: teamId,
      teamName: teamName,
      name: hasNote ? '${reason.label}. "$text"' : reason.label,
    );
    return batch.commit().timeout(_timeout);
  }
}

final suspensionRepositoryProvider = Provider<SuspensionRepository>((ref) {
  return SuspensionRepository(ref.watch(firestoreProvider));
});

/// A team's suspension history (FA and the team's admins).
final suspensionHistoryProvider =
    StreamProvider.family<List<Suspension>, String>((ref, teamId) {
      return ref.watch(suspensionRepositoryProvider).watchHistory(teamId);
    });
