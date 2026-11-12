import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';

const _timeout = Duration(seconds: 15);

/// The FA appoints a match's officials (3.5a, mockups MO1–MO3).
///
/// Like the duty roster on the kitchen wall: the FA writes the names in,
/// and whoever is added, moved or crossed out gets a note, all in one
/// batch with the roster itself.
class OfficialsRepository {
  OfficialsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _all =>
      _db.collection(FirestorePaths.fixtureOfficials);

  /// FA: every match's officials this season, by match ID.
  Stream<Map<String, MatchOfficials>> watchSeason(String season) => _all
      .where('season', isEqualTo: season)
      .snapshots()
      .map(
        (snap) => {
          for (final doc in snap.docs)
            doc.id: MatchOfficials.fromMap(doc.id, doc.data()),
        },
      );

  /// One match's officials (the FA; the clubs from 24 hours before).
  Stream<MatchOfficials> watchOne(String fixtureId) => _all
      .doc(fixtureId)
      .snapshots()
      .map((doc) => MatchOfficials.fromMap(fixtureId, doc.data()));

  /// Saves [after] for [f] (was [before]). Each person newly in a place,
  /// or moved to another, is told; each person no longer in the match is
  /// told too.
  Future<void> save(
    Fixture f,
    MatchOfficials before,
    MatchOfficials after, {
    required User by,
  }) {
    final writer = NotificationWriter(_db);
    final line = appointmentLine(f);
    final batch = _db.batch()
      ..set(_all.doc(f.id), after.toMap(season: f.season, by: by.uid));
    for (final MapEntry(key: place, value: who) in after.places.entries) {
      if (before.placeOf(who.uid) == place) continue;
      writer.forPersonInBatch(
        batch,
        kind: NotificationKind.appointed,
        uid: who.uid,
        targetId: f.id,
        line: '${youAre(place)}${AppNotification.lineBreak}$line.',
      );
    }
    for (final who in before.places.values) {
      if (after.placeOf(who.uid) != null) continue;
      writer.forPersonInBatch(
        batch,
        kind: NotificationKind.appointmentRemoved,
        uid: who.uid,
        targetId: f.id,
        line: 'Taken off${AppNotification.lineBreak}$line.',
      );
    }
    return batch.commit().timeout(_timeout);
  }

  /// 3.5b (RD3): the person in [place] can't make it, with why. Their
  /// reason goes on the match's officials (the FA sees it beside the
  /// name) and a note goes to the FA, in one batch. The FA appoints
  /// someone else (that clears it).
  Future<void> cantMakeIt(
    Fixture f, {
    required OfficialPlace place,
    required AppointedOfficial me,
    required String reason,
  }) {
    final why = reason.trim();
    final batch = _db.batch()
      ..update(_all.doc(f.id), {
        FieldPath(['cantMake', me.uid]): {'reason': why},
      });
    NotificationWriter(_db).forFaInBatch(
      batch,
      kind: NotificationKind.cantMakeIt,
      teamId: '',
      teamName: me.name,
      targetId: f.id,
      name:
          '${me.name} (${place.label})${AppNotification.lineBreak}'
          '${appointmentLine(f)}. "$why"',
    );
    return batch.commit().timeout(_timeout);
  }

  /// A person's own appointments (referees, and FA officials as
  /// commissioner), by match ID.
  Stream<Map<String, MatchOfficials>> watchMine(String uid) => _all
      .where('officialIds', arrayContains: uid)
      .snapshots()
      .map(
        (snap) => {
          for (final doc in snap.docs)
            doc.id: MatchOfficials.fromMap(doc.id, doc.data()),
        },
      );

  /// "You are the referee", "You are assistant 1"…
  static String youAre(OfficialPlace place) => switch (place) {
    OfficialPlace.referee => 'You are the referee',
    OfficialPlace.assistant1 => 'You are assistant 1',
    OfficialPlace.assistant2 => 'You are assistant 2',
    OfficialPlace.fourth => 'You are the 4th official',
    OfficialPlace.commissioner => 'You are the commissioner',
  };
}

final officialsRepositoryProvider = Provider<OfficialsRepository>((ref) {
  return OfficialsRepository(ref.watch(firestoreProvider));
});

/// FA: the season's officials by match ID.
final seasonOfficialsProvider = StreamProvider<Map<String, MatchOfficials>>((
  ref,
) {
  return ref.watch(officialsRepositoryProvider).watchSeason(Season.current);
});

/// The signed-in person's appointments, by match ID (3.5b).
final myAppointmentsProvider = StreamProvider<Map<String, MatchOfficials>>((
  ref,
) {
  final uid = ref.watch(appUserProvider).value?.uid;
  if (uid == null) return Stream.value(const {});
  return ref.watch(officialsRepositoryProvider).watchMine(uid);
});

/// One match's officials (an empty one when nobody is appointed yet).
final matchOfficialsProvider = StreamProvider.family<MatchOfficials, String>((
  ref,
  fixtureId,
) {
  return ref.watch(officialsRepositoryProvider).watchOne(fixtureId);
});
