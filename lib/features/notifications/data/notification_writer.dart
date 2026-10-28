import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';

/// Adds one event to the right grouped notification, inside the batch or
/// transaction that does the action itself (so it can never go missing).
///
/// The document ID is the same for every event of the same kind, for the
/// same audience and team, on the same day, e.g.
/// `team-royal_playersApproved_2026-10-24`. The first event creates it;
/// the next ones update it: count + 1, the name added, updatedAt renewed
/// (so it shows as new again, but still as ONE notification).
class NotificationWriter {
  const NotificationWriter(this._db);

  final FirebaseFirestore _db;

  /// '2026-10-24' (the day in Ghana, which is UTC).
  static String dayKey([DateTime? when]) {
    final d = (when ?? DateTime.now()).toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  ({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data})
      _entry({
    required String audience, // 'fa' or 'team:<teamId>'
    required NotificationKind kind,
    required String teamId,
    required String teamName,
    required String name,
    String? groupKey,
  }) {
    final day = dayKey();
    final safeAudience = audience.replaceAll(':', '-');
    // Usually one notification per team; [groupKey] groups several teams
    // (e.g. all of today's team requests in one).
    final id = '${safeAudience}_${kind.name}_${groupKey ?? teamId}_$day';
    return (
      ref: _db.doc(FirestorePaths.notification(id)),
      data: {
        'audience': audience,
        'kind': kind.name,
        'teamId': teamId,
        'teamName': teamName,
        'names': FieldValue.arrayUnion([name]),
        'count': FieldValue.increment(1),
        'day': day,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// For a team's bell (written by the FA).
  void forTeamInBatch(
    WriteBatch batch, {
    required NotificationKind kind,
    required String teamId,
    required String teamName,
    required String name,
  }) {
    final e = _entry(
      audience: 'team:$teamId',
      kind: kind,
      teamId: teamId,
      teamName: teamName,
      name: name,
    );
    batch.set(e.ref, e.data, SetOptions(merge: true));
  }

  void forTeamInTransaction(
    Transaction tx, {
    required NotificationKind kind,
    required String teamId,
    required String teamName,
    required String name,
  }) {
    final e = _entry(
      audience: 'team:$teamId',
      kind: kind,
      teamId: teamId,
      teamName: teamName,
      name: name,
    );
    tx.set(e.ref, e.data, SetOptions(merge: true));
  }

  /// For the FA's bell (written by teams, clubs and invited people).
  /// Team requests from every club are grouped into one a day:
  /// "3 new team requests: Afransi Stars, Royal Unique FC and Golden Unity".
  void forFaInBatch(
    WriteBatch batch, {
    required NotificationKind kind,
    required String teamId,
    required String teamName,
    required String name,
  }) {
    final e = _entry(
      audience: 'fa',
      kind: kind,
      teamId: teamId,
      teamName: teamName,
      name: name,
      groupKey: kind == NotificationKind.teamRequest ? 'all' : null,
    );
    batch.set(e.ref, e.data, SetOptions(merge: true));
  }
}
