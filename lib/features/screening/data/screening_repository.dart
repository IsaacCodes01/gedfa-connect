import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/announcement.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/screening/domain/screening_day.dart';

const _timeout = Duration(seconds: 15);

/// Juvenile screening days (2.14b). Each save or cancel also writes an
/// announcement to Juvenile teams, in the same batch: both happen, or
/// neither does.
class ScreeningRepository {
  ScreeningRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _days =>
      _db.collection(FirestorePaths.screeningDays);

  /// Today's and later screening days, soonest first. A day stays in the
  /// list until midnight after it (the "until the day after" rule).
  Stream<List<ScreeningDay>> watchUpcoming() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return _days
        .where('startsAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .orderBy('startsAt')
        .snapshots()
        .map((snap) => [
              for (final doc in snap.docs)
                ?ScreeningDay.fromMap(doc.id, doc.data()),
            ]);
  }

  /// One day, live (the decision screen, 2.14c). Null once cancelled.
  Stream<ScreeningDay?> watchOne(String id) {
    return _days.doc(id).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : ScreeningDay.fromMap(doc.id, data);
    });
  }

  /// "Save and announce": the day plus an announcement to Juvenile teams.
  Future<void> create({
    required DateTime startsAt,
    required String venue,
    required List<AgeGroup> groups,
    required String note,
    required User by,
  }) {
    final dayRef = _days.doc();
    final announcementRef =
        _db.collection(FirestorePaths.announcements).doc();
    final sorted = [...groups]..sort((a, b) => a.index.compareTo(b.index));
    final draft = ScreeningDay(
      id: dayRef.id,
      startsAt: startsAt,
      venue: venue.trim(),
      groups: sorted,
      note: note.trim(),
      announcementId: announcementRef.id,
    );

    // "Bring: …" only when the FA typed something (Isaac, 3 Nov 2026)
    final bring = draft.note.isEmpty ? '' : '\nBring: ${draft.note}';
    final batch = _db.batch()
      ..set(
        announcementRef,
        _announcement(
          title: 'Juvenile screening: ${draft.dateText}',
          body: '${draft.groupsText} players · ${draft.venue} · '
              '${draft.timeText}.$bring\nOnly children screened that day '
              'can play this season.',
          by: by,
        ),
      )
      ..set(dayRef, {
        'startsAt': Timestamp.fromDate(startsAt),
        'venue': draft.venue,
        'groups': [for (final g in sorted) g.label],
        if (draft.note.isNotEmpty) 'note': draft.note,
        'announcementId': announcementRef.id,
        'season': Season.current,
        'createdBy': by.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    return batch.commit().timeout(_timeout);
  }

  /// Cancels a day: removes it and its announcement, and tells Juvenile
  /// teams it is cancelled (a new announcement), with the FA's [reason]
  /// if one was typed.
  Future<void> cancel(
    ScreeningDay day, {
    required String reason,
    required User by,
  }) {
    // "Reason: The park is booked." (one full stop, even if they typed one)
    final text = reason.trim().replaceAll(RegExp(r'[.!\s]+$'), '');
    final why = text.isEmpty ? '' : ' Reason: $text.';
    final batch = _db.batch()
      ..delete(_days.doc(day.id))
      ..set(
        _db.collection(FirestorePaths.announcements).doc(),
        _announcement(
          title: 'Screening cancelled: ${day.dateText}',
          body: 'The ${day.groupsText} screening on ${day.dateText} at '
              '${day.venue} is cancelled.$why The FA will announce a new '
              'day.',
          by: by,
        ),
      );
    if (day.announcementId.isNotEmpty) {
      batch.delete(
        _db.doc(FirestorePaths.announcement(day.announcementId)),
      );
    }
    return batch.commit().timeout(_timeout);
  }

  /// The same fields as an announcement from More › Announcements.
  static Map<String, dynamic> _announcement({
    required String title,
    required String body,
    required User by,
  }) {
    final name = by.displayName?.trim();
    return {
      'title': title,
      'body': body,
      'to': Audience.juvenile.name,
      'important': true,
      'pinned': false,
      'createdBy': by.uid,
      'createdByName': name == null || name.isEmpty ? 'FA' : name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

final screeningRepositoryProvider = Provider<ScreeningRepository>((ref) {
  return ScreeningRepository(ref.watch(firestoreProvider));
});

/// One screening day, live.
final screeningDayProvider =
    StreamProvider.family<ScreeningDay?, String>((ref, id) {
  return ref.watch(screeningRepositoryProvider).watchOne(id);
});

/// Today's and later screening days, soonest first (FA and teams).
final upcomingScreeningsProvider =
    StreamProvider<List<ScreeningDay>>((ref) {
  return ref.watch(screeningRepositoryProvider).watchUpcoming();
});
