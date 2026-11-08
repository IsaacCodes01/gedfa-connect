import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';

const _timeout = Duration(seconds: 15);

/// Cups and galas (3.0c). In 3.0c1 the FA makes one; the draw (3.0c2)
/// writes its matches.
class CupRepository {
  CupRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _cups =>
      _db.collection(FirestorePaths.cups);

  /// Every cup and gala of the season, newest first.
  Stream<List<Cup>> watchSeason(String season) => _cups
      .where('season', isEqualTo: season)
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs) Cup.fromMap(doc.id, doc.data()),
          ]..sort((a, b) => (b.createdAt ?? DateTime(9999))
              .compareTo(a.createdAt ?? DateTime(9999))));

  /// "Save and go to the draw": a new cup, not drawn yet. Returns its ID.
  Future<String> create(Cup cup, {required User by}) async {
    final ref = _cups.doc();
    await ref.set({
      ...cup.toMap(),
      'createdBy': by.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': by.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
    return ref.id;
  }
}

final cupRepositoryProvider = Provider<CupRepository>((ref) {
  return CupRepository(ref.watch(firestoreProvider));
});

/// The season's cups and galas, live (C1).
final seasonCupsProvider = StreamProvider<List<Cup>>((ref) {
  return ref.watch(cupRepositoryProvider).watchSeason(Season.current);
});
