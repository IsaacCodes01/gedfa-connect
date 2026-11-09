import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup_changes.dart';
import 'package:gedfa_connect/features/fixtures/domain/postpone_plan.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';

const _timeout = Duration(seconds: 15);

/// Cups and galas (3.0c). The FA makes one (3.0c1), changes or deletes it
/// (3.0c1b), postpones a Gala (3.0c1c); the draw (3.0c2) writes its matches. Every write adds lines to
/// the cup's history in the same batch.
class CupRepository {
  CupRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _cups =>
      _db.collection(FirestorePaths.cups);

  CollectionReference<Map<String, dynamic>> _history(String cupId) =>
      _db.collection(FirestorePaths.cupHistory(cupId));

  /// Every cup and gala of the season, newest first.
  Stream<List<Cup>> watchSeason(String season) => _cups
      .where('season', isEqualTo: season)
      .snapshots()
      .map(
        (snap) =>
            [for (final doc in snap.docs) Cup.fromMap(doc.id, doc.data())]
              ..sort(
                (a, b) => (b.createdAt ?? DateTime(9999)).compareTo(
                  a.createdAt ?? DateTime(9999),
                ),
              ),
      );

  /// One cup, live; null once it is deleted.
  Stream<Cup?> watch(String cupId) => _cups
      .doc(cupId)
      .snapshots()
      .map((doc) => doc.exists ? Cup.fromMap(doc.id, doc.data()!) : null);

  /// The cup's history, newest first (C7).
  Stream<List<CupHistoryLine>> watchHistory(String cupId) =>
      _history(cupId).snapshots().map(
        (snap) =>
            [
              for (final doc in snap.docs)
                CupHistoryLine.fromMap(doc.id, doc.data()),
            ]..sort(
              (a, b) =>
                  (b.at ?? DateTime(9999)).compareTo(a.at ?? DateTime(9999)),
            ),
      );

  /// "Save and go to the draw": a new cup, not drawn yet, and "Cup made"
  /// in its history. Returns its ID.
  Future<String> create(Cup cup, {required User by}) async {
    final ref = _cups.doc();
    final batch = _db.batch()
      ..set(ref, {
        ...cup.toMap(),
        'createdBy': by.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedBy': by.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    _addLines(batch, ref.id, [cupMadeLine(cup)], by);
    await batch.commit().timeout(_timeout);
    return ref.id;
  }

  /// "Change" (C8), only before the draw: the whole cup again, and one
  /// history line per change ([lines], from `cupChanges`). Who made it and
  /// when stay as they were.
  Future<void> update(Cup after, List<String> lines, {required User by}) async {
    if (lines.isEmpty) return;
    final data = after.toMap();
    final batch = _db.batch()
      ..update(_cups.doc(after.id), {
        ...data,
        // A part that no longer applies goes (e.g. a gala made a cup)
        if (!data.containsKey('ageGroup')) 'ageGroup': FieldValue.delete(),
        if (!data.containsKey('gala')) 'gala': FieldValue.delete(),
        'updatedBy': by.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    _addLines(batch, after.id, lines, by);
    await batch.commit().timeout(_timeout);
  }

  /// "Postpone" a Gala (3.0c1c, mockup C10): its days move [days] later,
  /// with a line in its history and a note in every club's bell, in one
  /// batch. [teamNames]: team ID to name, for the bells. (A drawn cup's
  /// matches move with `FixtureRepository.startPostpone`.)
  Future<void> postponeGala(
    Cup cup,
    int days, {
    required String reason,
    required Map<String, String> teamNames,
    required User by,
  }) async {
    final old = cup.gala!;
    final gala = GalaSettings(
      ground: old.ground,
      firstDay: shiftDays(old.firstDay, days),
      lastDay: shiftDays(old.lastDay, days),
      kickoffHour: old.kickoffHour,
      kickoffMinute: old.kickoffMinute,
      gapMinutes: old.gapMinutes,
    );
    final why = '${reason.trim().replaceAll(RegExp(r'[.!\s]+$'), '')}.';
    final batch = _db.batch()
      ..update(_cups.doc(cup.id), {
        'gala': gala.toMap(),
        'updatedBy': by.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    _addLines(batch, cup.id, [
      'Postponed ${laterLabel(days)}: ${galaDays(old)} → ${galaDays(gala)}. '
          '$why',
    ], by);
    for (final teamId in {for (final e in cup.entries) e.teamId}) {
      NotificationWriter(_db).forTeamInBatch(
        batch,
        kind: NotificationKind.fixturePostponed,
        teamId: teamId,
        teamName: teamNames[teamId] ?? '',
        name:
            '${cup.name} postponed ${laterLabel(days)}: now '
            '${galaDays(gala)} at ${gala.ground}. $why',
      );
    }
    await batch.commit().timeout(_timeout);
  }

  /// "Delete the cup" (C9): everything goes, the cup and its history
  /// (GEDFA, 8 Nov 2026). Its matches go too once there is a draw (3.0c2).
  Future<void> delete(String cupId) async {
    final history = await _history(cupId).get().timeout(_timeout);
    final batch = _db.batch();
    for (final doc in history.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_cups.doc(cupId));
    await batch.commit().timeout(_timeout);
  }

  void _addLines(WriteBatch batch, String cupId, List<String> lines, User by) {
    final name = by.displayName?.trim();
    for (final text in lines) {
      batch.set(_history(cupId).doc(), {
        'text': text.length > 200 ? '${text.substring(0, 199)}…' : text,
        'by': by.uid,
        'byName': name == null || name.isEmpty ? (by.email ?? 'FA') : name,
        'at': FieldValue.serverTimestamp(),
      });
    }
  }
}

final cupRepositoryProvider = Provider<CupRepository>((ref) {
  return CupRepository(ref.watch(firestoreProvider));
});

/// The season's cups and galas, live (C1).
final seasonCupsProvider = StreamProvider<List<Cup>>((ref) {
  return ref.watch(cupRepositoryProvider).watchSeason(Season.current);
});

/// One cup, live (C7); null once deleted.
final cupProvider = StreamProvider.family<Cup?, String>((ref, cupId) {
  return ref.watch(cupRepositoryProvider).watch(cupId);
});

/// A cup's history, newest first (C7).
final cupHistoryProvider = StreamProvider.family<List<CupHistoryLine>, String>((
  ref,
  cupId,
) {
  return ref.watch(cupRepositoryProvider).watchHistory(cupId);
});
