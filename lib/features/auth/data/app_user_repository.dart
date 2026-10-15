import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/domain/app_user.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final appUserProvider = StreamProvider<AppUser?>((ref) async* {
  final authUser = await ref.watch(authStateProvider.future);

  if (authUser == null) {
    yield null;
    return;
  }

  final docRef = ref
      .watch(firestoreProvider)
      .doc(FirestorePaths.user(authUser.uid));

  yield* docRef.snapshots().map((snapshot) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return AppUser(uid: authUser.uid, role: null);
    }
    return AppUser.fromMap(snapshot.id, data);
  });
});