import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/announcement.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';

const _timeout = Duration(seconds: 15);

/// When I last pressed "Mark all read", the notes I read one by one
/// (3.0f), and the pinned announcements I hid.
class ReadMark {
  const ReadMark({this.seenAt, this.reads = const {}, this.hidden = const []});

  final DateTime? seenAt;

  /// Note (or announcement) ID → the time it had when I read it.
  final Map<String, DateTime> reads;
  final List<String> hidden;

  /// Newer than my last "Mark all read".
  bool isNew(DateTime? time) =>
      time != null && (seenAt == null || time.isAfter(seenAt!));

  /// New, and not read on its own since it last changed. A grouped note
  /// that gets one more name has a newer time, so it is unread again.
  /// Compared in milliseconds: the web keeps no microseconds.
  bool isUnread(String id, DateTime? time) {
    if (!isNew(time)) return false;
    final read = reads[id];
    return read == null ||
        time!.millisecondsSinceEpoch > read.millisecondsSinceEpoch;
  }

  /// Read on its own before, then changed (shown on the details page).
  bool changedSinceRead(String id, DateTime? time) =>
      reads.containsKey(id) && isUnread(id, time);
}

/// Announcements, notifications and read marks (2.7 – 2.8).
class NotificationsRepository {
  NotificationsRepository(this._db);

  final FirebaseFirestore _db;

  // ---------- Notifications ----------

  // One audience's notifications ('fa' or 'team:<teamId>'), newest first.
  Stream<List<AppNotification>> watchNotifications(String audience) {
    return _db
        .collection(FirestorePaths.notifications)
        .where('audience', isEqualTo: audience)
        .orderBy('updatedAt', descending: true)
        .limit(60)
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                ?AppNotification.fromMap(doc.id, doc.data()),
            ]);
  }

  Stream<ReadMark> watchReadMark(String uid) {
    return _db.doc(FirestorePaths.readMark(uid)).snapshots().map((snapshot) {
      final data = snapshot.data();
      final reads = data?['reads'];
      return ReadMark(
        seenAt: (data?['notificationsSeenAt'] as Timestamp?)?.toDate(),
        reads: {
          if (reads is Map)
            for (final e in reads.entries)
              if (e.value is Timestamp)
                e.key.toString(): (e.value as Timestamp).toDate(),
        },
        hidden: [
          for (final id in data?['hiddenAnnouncements'] as List<dynamic>? ??
              const [])
            id.toString(),
        ],
      );
    });
  }

  /// Everything is read: the one-by-one reads are not needed any more.
  Future<void> markAllRead(String uid) {
    return _db.doc(FirestorePaths.readMark(uid)).set(
      {
        'notificationsSeenAt': FieldValue.serverTimestamp(),
        'reads': <String, Object>{},
      },
      SetOptions(mergeFields: ['notificationsSeenAt', 'reads']),
    ).timeout(_timeout);
  }

  /// Marks one note (or announcement) read, as it is at [time] (3.0f).
  /// Only the IDs still in my bell ([keep]) are kept, so the map stays
  /// small (the rules allow 100).
  Future<void> markRead(
    String uid,
    ReadMark mark, {
    required String id,
    required DateTime time,
    required Set<String> keep,
  }) {
    final reads = <String, Object>{
      for (final e in mark.reads.entries)
        if (keep.contains(e.key) && e.key != id)
          e.key: Timestamp.fromDate(e.value),
      id: Timestamp.fromDate(time),
    };
    // mergeFields replaces the whole map (a plain merge would only add)
    return _db.doc(FirestorePaths.readMark(uid)).set(
      {'reads': reads},
      SetOptions(mergeFields: ['reads']),
    ).timeout(_timeout);
  }

  /// Hides a pinned announcement from my home screen (keeps the last 30).
  Future<void> hidePinned(String uid, ReadMark mark, String announcementId) {
    final hidden = [...mark.hidden, announcementId];
    return _db.doc(FirestorePaths.readMark(uid)).set(
      {
        'hiddenAnnouncements':
            hidden.length > 30 ? hidden.sublist(hidden.length - 30) : hidden,
      },
      SetOptions(merge: true),
    ).timeout(_timeout);
  }

  // ---------- Announcements ----------

  /// The announcements meant for these audiences, newest first.
  Stream<List<Announcement>> watchFor(List<Audience> audiences) {
    return _db
        .collection(FirestorePaths.announcements)
        .where('to', whereIn: [for (final a in audiences) a.name])
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map(_toAnnouncements);
  }

  /// FA: every announcement, newest first.
  Stream<List<Announcement>> watchAll() {
    return _db
        .collection(FirestorePaths.announcements)
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map(_toAnnouncements);
  }

  Stream<Announcement?> watchOne(String id) {
    return _db.doc(FirestorePaths.announcement(id)).snapshots().map((s) {
      final data = s.data();
      return data == null ? null : Announcement.fromMap(s.id, data);
    });
  }

  static List<Announcement> _toAnnouncements(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) =>
      [
        for (final doc in snapshot.docs)
          Announcement.fromMap(doc.id, doc.data()),
      ];

  /// FA: who has seen it. Key = team ID (teams) or uid (referees).
  Stream<Map<String, DateTime?>> watchSeen(String id) {
    return _db
        .collection(FirestorePaths.announcementSeenAll(id))
        .snapshots()
        .map((snapshot) => {
              for (final doc in snapshot.docs)
                doc.id: (doc.data()['at'] as Timestamp?)?.toDate(),
            });
  }

  Future<void> publish({
    required String title,
    required String body,
    required Audience to,
    required bool important,
    required bool pinned,
    required User by,
  }) {
    final name = by.displayName?.trim();
    return _db.collection(FirestorePaths.announcements).add({
      'title': title.trim(),
      'body': body.trim(),
      'to': to.name,
      'important': important,
      'pinned': pinned,
      'createdBy': by.uid,
      'createdByName': name == null || name.isEmpty ? 'FA' : name,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }

  Future<void> setPinned(String id, bool pinned) {
    return _db
        .doc(FirestorePaths.announcement(id))
        .update({'pinned': pinned}).timeout(_timeout);
  }

  Future<void> delete(String id) {
    return _db.doc(FirestorePaths.announcement(id)).delete().timeout(_timeout);
  }

  /// "Seen": my team (team admins) or me (referees) opened it.
  Future<void> markSeen(String id, {required String key, required String by}) {
    return _db.doc(FirestorePaths.announcementSeen(id, key)).set({
      'at': FieldValue.serverTimestamp(),
      'by': by,
    }).timeout(_timeout);
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(firestoreProvider));
});

// ---------- Who am I, for notifications ----------

// My notification audience: 'fa', 'team:<teamId>', or null (none yet).
final myAudienceProvider = Provider<String?>((ref) {
  final user = ref.watch(appUserProvider).value;
  return switch (user?.role) {
    UserRole.faAdmin => 'fa',
    UserRole.teamAdmin when (user?.teamId ?? '').isNotEmpty =>
      'team:${user!.teamId}',
    _ => null,
  };
});

/// The announcement audiences that include me.
final myAudiencesProvider = Provider<List<Audience>>((ref) {
  final user = ref.watch(appUserProvider).value;
  switch (user?.role) {
    case UserRole.faAdmin:
      return Audience.values;
    case UserRole.referee:
      return const [Audience.everyone, Audience.referees];
    case UserRole.teamAdmin:
      final team = ref.watch(myTeamProvider).value;
      return [
        Audience.everyone,
        Audience.teams,
        if (team?.categories.any((c) => c.name == 'division') ?? true)
          Audience.division,
        if (team?.categories.any((c) => c.name == 'juvenile') ?? false)
          Audience.juvenile,
      ];
    case null:
      return const [];
  }
});

final myNotificationsProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final audience = ref.watch(myAudienceProvider);
  if (audience == null) return Stream.value(const []);
  return ref.watch(notificationsRepositoryProvider).watchNotifications(audience);
});

/// FA: every announcement. Others: the ones meant for them.
final myAnnouncementsProvider = StreamProvider<List<Announcement>>((ref) {
  final audiences = ref.watch(myAudiencesProvider);
  if (audiences.isEmpty) return Stream.value(const []);
  final repo = ref.watch(notificationsRepositoryProvider);
  return audiences.length == Audience.values.length
      ? repo.watchAll()
      : repo.watchFor(audiences);
});

final readMarkProvider = StreamProvider<ReadMark>((ref) {
  final uid = ref.watch(appUserProvider).value?.uid;
  if (uid == null) return Stream.value(const ReadMark());
  return ref.watch(notificationsRepositoryProvider).watchReadMark(uid);
});

/// The red number on the bell: notifications and announcements newer than
/// my last "Mark all read" that I haven't opened since they changed.
final unreadCountProvider = Provider<int>((ref) {
  final mark = ref.watch(readMarkProvider).value;
  if (mark == null) return 0;
  final notifications = ref.watch(myNotificationsProvider).value ?? const [];
  final announcements = ref.watch(myAnnouncementsProvider).value ?? const [];
  final isFa = ref.watch(myAudienceProvider) == 'fa';
  return notifications.where((n) => mark.isUnread(n.id, n.updatedAt)).length +
      // The FA wrote the announcements, so they don't count as news for them
      (isFa
          ? 0
          : announcements
              .where((a) => mark.isUnread(a.id, a.createdAt))
              .length);
});

/// The newest pinned announcement for me that I haven't hidden.
final pinnedAnnouncementProvider = Provider<Announcement?>((ref) {
  final mark = ref.watch(readMarkProvider).value ?? const ReadMark();
  final announcements = ref.watch(myAnnouncementsProvider).value ?? const [];
  for (final a in announcements) {
    if (a.pinned && !mark.hidden.contains(a.id)) return a;
  }
  return null;
});

/// The IDs of the notes and announcements in my bell now: the only reads
/// worth keeping (3.0f).
final bellIdsProvider = Provider<Set<String>>((ref) {
  return {
    for (final n in ref.watch(myNotificationsProvider).value ?? const [])
      n.id,
    for (final a in ref.watch(myAnnouncementsProvider).value ?? const [])
      a.id,
  };
});

/// One of my notes, for its details page (3.0f). Null: not in my bell
/// (gone, or not mine).
final myNotificationProvider =
    Provider.family<AsyncValue<AppNotification?>, String>((ref, id) {
  return ref.watch(myNotificationsProvider).whenData(
        (notes) => notes.where((n) => n.id == id).firstOrNull,
      );
});

final announcementProvider =
    StreamProvider.family<Announcement?, String>((ref, id) {
  return ref.watch(notificationsRepositoryProvider).watchOne(id);
});

final announcementSeenProvider =
    StreamProvider.family<Map<String, DateTime?>, String>((ref, id) {
  return ref.watch(notificationsRepositoryProvider).watchSeen(id);
});
