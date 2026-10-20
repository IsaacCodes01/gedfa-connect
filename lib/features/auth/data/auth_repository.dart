import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const _timeout = Duration(seconds: 15);

class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth
        .signInWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        )
        .timeout(_timeout);
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth
        .createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        )
        .timeout(_timeout);

    await credential.user?.updateDisplayName(name.trim());
    await credential.user?.sendEmailVerification();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth
        .sendPasswordResetEmail(email: email.trim().toLowerCase())
        .timeout(_timeout);
  }

    Future<void> signInWithGoogle() async {
    if (!kIsWeb) {
      throw UnsupportedError('Google sign-in is web-only for now.');
    }

    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});

    await _auth.signInWithPopup(provider);
  }

    Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.sendEmailVerification().timeout(_timeout);
  }

  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload().timeout(_timeout);
    final verified = _auth.currentUser?.emailVerified ?? false;
    if (verified) await _auth.currentUser?.getIdToken(true);
    return verified;
  }

  Future<void> signOut() => _auth.signOut();

  // ---------- My profile ----------

  /// Like [authStateChanges], but also fires when the name or email of the
  /// signed-in user changes. Used by the profile screens.
  Stream<User?> userChanges() => _auth.userChanges();

  /// True if this account logs in with an email and password.
  /// False for Google-only accounts: Google manages their email and password.
  bool get hasPassword =>
      _auth.currentUser?.providerData
          .any((info) => info.providerId == EmailAuthProvider.PROVIDER_ID) ??
      false;

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    return user;
  }

  /// Saves a new full name on the account.
  Future<void> updateName(String name) async {
    final user = _requireUser();
    await user.updateDisplayName(name.trim()).timeout(_timeout);
    // Reload so userChanges() sends the new name to every screen.
    await user.reload().timeout(_timeout);
  }

  /// Emails the signed-in user a link to choose a new password.
  Future<void> sendPasswordResetToMe() async {
    final email = _requireUser().email;
    if (email == null) throw FirebaseAuthException(code: 'missing-email');
    await sendPasswordReset(email);
  }

  /// Checks the current password, then emails a confirmation link to
  /// [newEmail]. The email only changes when the link is opened.
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _requireUser();
    final email = user.email;
    if (email == null) throw FirebaseAuthException(code: 'missing-email');

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential).timeout(_timeout);
    await user
        .verifyBeforeUpdateEmail(newEmail.trim().toLowerCase())
        .timeout(_timeout);
  }
}

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The signed-in user, updated live when their name or email changes.
/// Screens use this; the router keeps using [authStateProvider].
final currentUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges();
});