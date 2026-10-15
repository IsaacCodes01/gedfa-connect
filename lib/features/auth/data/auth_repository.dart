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
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() => _auth.signOut();
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