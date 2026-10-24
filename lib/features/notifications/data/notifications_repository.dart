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

/// When I last opened my notifications, and the pinned announcements I hid.
class ReadMark {
  const ReadMark({this.seenAt, this.hidden = const []});

  final DateTime? seenAt;
  final List<String> hidden;

  bool isNew(DateTime? time) =>
      time != null && (seenAt == null || time.isAfter(seenAt!));
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
      return ReadMark(
        seenAt: (data?['notificationsSeenAt'] as Timestamp?)?.toDate(),
        hidden: [
          for (final id in data?['hiddenAnnouncements'] as List<dynamic>? ??
              const [])
            id.toString(),
        ],
      );
    });
  }

  Future<void> markAllRead(String uid) {
    return _db.doc(FirestorePaths.readMark(uid)).set(
      {'notificationsSeenAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
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
/// my last "Mark all read".
final unreadCountProvider = Provider<int>((ref) {
  final mark = ref.watch(readMarkProvider).value;
  if (mark == null) return 0;
  final notifications = ref.watch(myNotificationsProvider).value ?? const [];
  final announcements = ref.watch(myAnnouncementsProvider).value ?? const [];
  final isFa = ref.watch(myAudienceProvider) == 'fa';
  return notifications.where((n) => mark.isNew(n.updatedAt)).length +
      // The FA wrote the announcements, so they don't count as news for them
      (isFa
          ? 0
          : announcements.where((a) => mark.isNew(a.createdAt)).length);
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

final announcementProvider =
    StreamProvider.family<Announcement?, String>((ref, id) {
  return ref.watch(notificationsRepositoryProvider).watchOne(id);
});

final announcementSeenProvider =
    StreamProvider.family<Map<String, DateTime?>, String>((ref, id) {
  return ref.watch(notificationsRepositoryProvider).watchSeen(id);
});
