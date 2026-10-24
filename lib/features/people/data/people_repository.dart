import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/people/domain/invite.dart';
import 'package:gedfa_connect/features/people/domain/member.dart';
import 'package:gedfa_connect/features/people/domain/role_log_entry.dart';

const _timeout = Duration(seconds: 15);

/// Invitations, FA admins and referees, and the role history.
///
/// Every change is ONE batch: the change itself plus a role-history line,
/// so the history can never miss a step.
class PeopleRepository {
  PeopleRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _inviteRef(String email) =>
      _db.doc(FirestorePaths.invite(inviteIdFor(email)));

  /// A new role-history line (Firestore picks the ID).
  DocumentReference<Map<String, dynamic>> _newLogRef() =>
      _db.collection(FirestorePaths.roleLog).doc();

  Map<String, dynamic> _log({
    required String email,
    required String name,
    required UserRole role,
    required String action,
    required User by,
    String? uid,
  }) =>
      {
        'email': inviteIdFor(email),
        'name': name,
        'role': role.name,
        'action': action,
        'uid': ?uid,
        'by': by.uid,
        'byName': _nameOf(by),
        'at': FieldValue.serverTimestamp(),
      };

  static String _nameOf(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return user.email ?? 'FA';
  }

  // ---------- Reading (FA) ----------

  /// FA admins and referees, live, chairman first, then A to Z.
  Stream<List<Member>> watchMembers() {
    return _db
        .collection(FirestorePaths.users)
        .where('role', whereIn: [UserRole.faAdmin.name, UserRole.referee.name])
        .snapshots()
        .map((snapshot) {
      final members = [
        for (final doc in snapshot.docs) Member.fromMap(doc.id, doc.data()),
      ];
      members.sort((a, b) {
        if (a.isChairman != b.isChairman) return a.isChairman ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return members;
    });
  }

  /// Invitations still waiting (including expired ones, so the FA can
  /// cancel or re-send them), newest first.
  Stream<List<Invite>> watchPendingInvites() {
    return _db
        .collection(FirestorePaths.invites)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final invites = [
        for (final doc in snapshot.docs) Invite.fromMap(doc.id, doc.data()),
      ];
      final zero = DateTime.fromMillisecondsSinceEpoch(0);
      invites.sort(
        (a, b) => (b.createdAt ?? zero).compareTo(a.createdAt ?? zero),
      );
      return invites;
    });
  }

  /// One invitation, live (null when cancelled, declined or removed).
  Stream<Invite?> watchInvite(String email) {
    return _inviteRef(email).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : Invite.fromMap(snapshot.id, data);
    });
  }

  /// One member, live (null once the role is removed).
  Stream<Member?> watchMember(String uid) {
    return _db.doc(FirestorePaths.user(uid)).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : Member.fromMap(snapshot.id, data);
    });
  }

  /// The role history of one email, oldest first.
  Stream<List<RoleLogEntry>> watchHistory(String email) {
    return _db
        .collection(FirestorePaths.roleLog)
        .where('email', isEqualTo: inviteIdFor(email))
        .snapshots()
        .map((snapshot) {
      final entries = [
        for (final doc in snapshot.docs) RoleLogEntry.fromMap(doc.data()),
      ];
      final zero = DateTime.fromMillisecondsSinceEpoch(0);
      entries.sort((a, b) => (a.at ?? zero).compareTo(b.at ?? zero));
      return entries;
    });
  }

  // ---------- Writing (FA) ----------

  /// Creates an invitation for [email] and returns its ID.
  ///
  /// An old invitation for the same email that is no longer open (expired)
  /// is cleared first. An open one, or an email that already has a role,
  /// is refused with a clear message.
  Future<String> invite({
    required String name,
    required String email,
    required UserRole role,
    required User by,
  }) async {
    final id = inviteIdFor(email);

    final members = await _db
        .collection(FirestorePaths.users)
        .where('email', isEqualTo: id)
        .limit(1)
        .get()
        .timeout(_timeout);
    if (members.docs.isNotEmpty) throw const AlreadyMemberException();

    final existing = await _inviteRef(id).get().timeout(_timeout);
    final old = existing.data();
    if (old != null) {
      if (Invite.fromMap(id, old).isOpen) throw const InviteExistsException();
      await _inviteRef(id).delete().timeout(_timeout); // expired: clear it
    }

    final batch = _db.batch()
      ..set(_inviteRef(id), {
        'email': id,
        'name': name.trim(),
        'role': role.name,
        'status': 'pending',
        'invitedBy': by.uid,
        'invitedByName': _nameOf(by),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt':
            Timestamp.fromDate(DateTime.now().add(inviteLifetime)),
      })
      ..set(_newLogRef(), _log(
        email: id,
        name: name.trim(),
        role: role,
        action: 'invited',
        by: by,
      ));
    await batch.commit().timeout(_timeout);
    return id;
  }

  /// Cancels an invitation that was not accepted yet.
  Future<void> cancel(Invite invite, {required User by}) {
    final batch = _db.batch()
      ..delete(_inviteRef(invite.email))
      ..set(_newLogRef(), _log(
        email: invite.email,
        name: invite.name,
        role: invite.role,
        action: 'cancelled',
        by: by,
      ));
    return batch.commit().timeout(_timeout);
  }

  /// Removes a member's role. Their account stays; they become a user
  /// with no role. The accepted invitation is cleared, so they can be
  /// invited again later.
  Future<void> removeRole(Member member, {required User by}) {
    final batch = _db.batch()..delete(_db.doc(FirestorePaths.user(member.uid)));
    final inviteId = member.inviteId;
    if (inviteId != null) batch.delete(_inviteRef(inviteId));
    batch.set(_newLogRef(), _log(
      email: member.email,
      name: member.name,
      role: member.role,
      action: 'removed',
      uid: member.uid,
      by: by,
    ));
    return batch.commit().timeout(_timeout);
  }

  // ---------- The invited person ----------

  /// Accepts: my user document with the invited role + invitation accepted
  /// + history line, all at once.
  Future<void> accept(Invite invite, {required User me}) {
    final name = _nameOf(me) == me.email ? invite.name : _nameOf(me);
    final batch = _db.batch()
      ..set(_db.doc(FirestorePaths.user(me.uid)), {
        'role': invite.role.name,
        'name': name,
        'email': inviteIdFor(me.email ?? ''),
        'inviteId': inviteIdFor(invite.email),
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(_inviteRef(invite.email), {
        'status': 'accepted',
        'acceptedBy': me.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      })
      ..set(_newLogRef(), _log(
        email: invite.email,
        name: name,
        role: invite.role,
        action: 'accepted',
        uid: me.uid,
        by: me,
      ));
    // The FA's bell: "Kwesi Arthur (Referee)"
    NotificationWriter(_db).forFaInBatch(
      batch,
      kind: NotificationKind.inviteAccepted,
      teamId: '',
      teamName: '',
      name: '$name (${roleLabelFor(invite.role)})',
    );
    return batch.commit().timeout(_timeout);
  }

  /// Declines: the invitation is deleted, with a history line.
  Future<void> decline(Invite invite, {required User me}) {
    final batch = _db.batch()
      ..delete(_inviteRef(invite.email))
      ..set(_newLogRef(), _log(
        email: invite.email,
        name: invite.name,
        role: invite.role,
        action: 'declined',
        uid: me.uid,
        by: me,
      ));
    return batch.commit().timeout(_timeout);
  }
}

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) {
  return PeopleRepository(ref.watch(firestoreProvider));
});

/// FA: admins and referees, live.
final membersProvider = StreamProvider<List<Member>>((ref) {
  return ref.watch(peopleRepositoryProvider).watchMembers();
});

/// FA: invitations still waiting, live.
final pendingInvitesProvider = StreamProvider<List<Invite>>((ref) {
  return ref.watch(peopleRepositoryProvider).watchPendingInvites();
});

final inviteProvider =
    StreamProvider.family<Invite?, String>((ref, email) {
  return ref.watch(peopleRepositoryProvider).watchInvite(email);
});

final memberProvider = StreamProvider.family<Member?, String>((ref, uid) {
  return ref.watch(peopleRepositoryProvider).watchMember(uid);
});

final roleHistoryProvider =
    StreamProvider.family<List<RoleLogEntry>, String>((ref, email) {
  return ref.watch(peopleRepositoryProvider).watchHistory(email);
});

/// The signed-in person's own invitation, if their confirmed email has one
/// that is still open. Used by the Welcome screen.
final myOpenInviteProvider = StreamProvider<Invite?>((ref) async* {
  final user = await ref.watch(authStateProvider.future);
  final email = user?.email;
  if (user == null || email == null || !user.emailVerified) {
    yield null;
    return;
  }
  yield* ref
      .watch(peopleRepositoryProvider)
      .watchInvite(email)
      .map((invite) => invite != null && invite.isOpen ? invite : null);
});
