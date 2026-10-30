import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/domain/app_user.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';

const _timeout = Duration(seconds: 15);

/// One change in the history: who, when, and what moved from → to.
class SettingsChange {
  const SettingsChange({
    required this.byName,
    required this.changes,
    this.at,
  });

  final String byName;
  final DateTime? at;

  /// "Player registration: open → closed"
  final List<String> changes;
}

/// `settings/league` and its history (2.13d).
class LeagueSettingsRepository {
  LeagueSettingsRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.doc(FirestorePaths.leagueSettings);

  /// Live. Missing document = the defaults (everything open, 30 / 16 / 5).
  Stream<LeagueSettings> watch() => _ref
      .snapshots()
      .map((snapshot) => LeagueSettings.fromMap(snapshot.data()));

  /// FA: saves only what changed, in ONE batch with:
  /// - a line in the history (who, when, from → to), and
  /// - a note in the FA's bell when registration opens or closes, so every
  ///   official sees it ("Player registration opened by Kofi Mensah").
  Future<void> save(
    LeagueSettings after, {
    required LeagueSettings before,
    required AppUser by,
  }) {
    final changes = after.changesFrom(before);
    if (changes.isEmpty) return Future.value();
    final name = (by.displayName ?? '').trim().isEmpty
        ? (by.email ?? 'An FA official')
        : by.displayName!.trim();
    final values = after.toMap();

    final batch = _db.batch()
      ..set(
        _ref,
        {
          for (final field in changes.keys) field: values[field],
          'updatedBy': by.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      )
      ..set(_db.collection(FirestorePaths.settingsLog).doc(), {
        'by': by.uid,
        'byName': name,
        'at': FieldValue.serverTimestamp(),
        'changes': {
          for (final e in changes.entries)
            e.key: {'from': e.value.from, 'to': e.value.to},
        },
      });

    for (final field in const ['teamRegistrationOpen', 'playerRegistrationOpen']) {
      final change = changes[field];
      if (change == null) continue;
      final opened = change.to == true;
      NotificationWriter(_db).forFaInBatch(
        batch,
        kind: NotificationKind.registrationChanged,
        teamId: 'league',
        teamName: 'GEDFA',
        name: '${LeagueSettings.labels[field]} '
            '${opened ? 'opened' : 'closed'} by $name',
      );
    }
    return batch.commit().timeout(_timeout);
  }

  /// FA: the last 20 changes, newest first.
  Stream<List<SettingsChange>> watchHistory() {
    return _db
        .collection(FirestorePaths.settingsLog)
        .orderBy('at', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                SettingsChange(
                  byName: doc.data()['byName'] as String? ?? '',
                  at: (doc.data()['at'] as Timestamp?)?.toDate(),
                  changes: [
                    for (final e in (doc.data()['changes']
                                as Map<String, dynamic>? ??
                            const {})
                        .entries)
                      '${LeagueSettings.labels[e.key] ?? e.key}: '
                          '${settingText(e.key, (e.value as Map)['from'] as Object)}'
                          ' → '
                          '${settingText(e.key, (e.value as Map)['to'] as Object)}',
                  ],
                ),
            ]);
  }
}

final leagueSettingsRepositoryProvider =
    Provider<LeagueSettingsRepository>((ref) {
  return LeagueSettingsRepository(ref.watch(firestoreProvider));
});

/// The league settings, live. Before sign-in (the rules need a signed-in
/// user) everyone gets the defaults.
final leagueSettingsProvider = StreamProvider<LeagueSettings>((ref) async* {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield const LeagueSettings();
    return;
  }
  yield* ref.watch(leagueSettingsRepositoryProvider).watch();
});

/// FA: the history of changes.
final settingsHistoryProvider = StreamProvider<List<SettingsChange>>((ref) {
  return ref.watch(leagueSettingsRepositoryProvider).watchHistory();
});
