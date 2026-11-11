import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_picks.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_roles.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';

const _timeout = Duration(seconds: 15);

/// Team sheets (3.1): `teamSheets/{fixtureId}_{teamId}`.
class TeamSheetRepository {
  TeamSheetRepository(this._db);

  final FirebaseFirestore _db;

  /// One team's sheet for one match, live; null until it is first saved.
  Stream<TeamSheet?> watch(String fixtureId, String teamId) => _db
      .doc(FirestorePaths.teamSheet(fixtureId, teamId))
      .snapshots()
      .map((snap) {
        final data = snap.data();
        return data == null ? null : TeamSheet.fromMap(data);
      });

  /// Every sheet of one team, live (the rules let a team list its own).
  Stream<List<TeamSheet>> watchTeam(String teamId) => _db
      .collection(FirestorePaths.teamSheets)
      .where('teamId', isEqualTo: teamId)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) TeamSheet.fromMap(d.data())]);

  /// Saves the whole sheet (saving again replaces it). The rules check
  /// the match, the limits, that every player is approved, and the roles:
  /// [roles] fitted to [picks], [numbers] for every picked player, and
  /// [officials] with the team manager first and the head coach second.
  Future<void> save({
    required Fixture fixture,
    required String teamId,
    required SheetPicks picks,
    required SheetRoles roles,
    required Map<String, int> numbers,
    required List<Official> officials,
    required List<SheetPlayer> players,
    required String uid,
  }) {
    // Checked here first so the team is told why; the rules refuse it too
    final due = fixture.sheetDueAt;
    if (!fixture.isScheduled || due == null || !DateTime.now().isBefore(due)) {
      throw const SheetLockedException();
    }
    return _db
        .doc(FirestorePaths.teamSheet(fixture.id, teamId))
        .set({
          'fixtureId': fixture.id,
          'teamId': teamId,
          'category': fixture.category.name,
          'ageGroup': ?fixture.ageGroup?.label,
          'starters': picks.starters,
          'bench': picks.bench,
          'captainId': roles.captainId,
          'viceCaptainId': ?roles.viceCaptainId,
          'goalkeeperId': roles.goalkeeperId,
          'numbers': numbers,
          // Copies: the sheet keeps them even if Team profile changes later.
          // No phone numbers (the opponent sees the sheet after the lock).
          'officials': [
            for (final o in officials)
              {
                'role': o.role.name,
                'name': o.name.trim(),
                'title': ?o.title?.trim(),
                'licence': ?o.licence,
              },
          ],
          // Copies for the FA and the opponent (3.2): no photo, no birth date
          'players': {for (final p in players) p.id: p.toMap()},
          'savedBy': uid,
          'savedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_timeout);
  }
}

final teamSheetRepositoryProvider = Provider<TeamSheetRepository>((ref) {
  return TeamSheetRepository(ref.watch(firestoreProvider));
});

/// My team's sheets by match ID, live (3.1c: the sheet lines on Home and
/// Fixtures, Needs you, and "Use last sheet").
final myTeamSheetsProvider = StreamProvider<Map<String, TeamSheet>>((
  ref,
) async* {
  final team = await ref.watch(myTeamProvider.future);
  if (team == null) {
    yield const {};
    return;
  }
  yield* ref
      .watch(teamSheetRepositoryProvider)
      .watchTeam(team.id)
      .map((list) => {for (final s in list) s.fixtureId: s});
});

/// One sheet by its ID parts, live: `(fixtureId, teamId)`.
final teamSheetProvider = StreamProvider.family<TeamSheet?, (String, String)>((
  ref,
  key,
) {
  return ref.watch(teamSheetRepositoryProvider).watch(key.$1, key.$2);
});
