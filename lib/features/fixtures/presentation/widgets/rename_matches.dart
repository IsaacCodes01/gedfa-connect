import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/widgets/sending.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

/// Renaming the matches stopped (no connection…). The new name itself is
/// approved; the team's page offers "Finish renaming" (mockup R5).
class RenameStoppedException implements Exception {
  const RenameStoppedException(this.cause);

  final Object cause;

  String get message =>
      'Approved. Renaming the matches stopped '
      '(${appErrorMessage(cause)}). Finish it from the team\'s page: '
      'Finish renaming.';
}

/// The matches of [team] that don't show its names yet (JSc2): its side's
/// name or short name is not the team's name for that competition now.
List<Fixture> staleMatchesOf(Team team, List<Fixture> season) => [
  for (final f in season)
    for (final side in [f.home, f.away])
      if (side.id == team.id &&
          (side.name != team.sideName(f.category) ||
              side.shortName != team.sideShortName(f.category)))
        f,
];

/// Renames [teamId] in all its matches with a progress dialog ("Renaming
/// matches… 12 of 34", mockup R4b). [newName] is for the dialog only.
/// Throws [RenameStoppedException] if it stops; running it again carries
/// on where it stopped.
Future<int> renameTeamMatches(
  BuildContext context,
  WidgetRef ref, {
  required String teamId,
  required String newName,
  DateTime? until,
}) async {
  final me = ref.read(authStateProvider).value;
  if (me == null) return 0;
  try {
    // S2 (M2): the sheet with the progress bar
    return await SendingSheet.run(
      context,
      title: 'Renaming matches to $newName…',
      unit: 'Match',
      task: (progress) => ref
          .read(fixtureRepositoryProvider)
          .renameTeam(
            teamId,
            until: until ?? DateTime.now(),
            by: me,
            onProgress: progress,
          ),
    );
  } catch (error) {
    throw RenameStoppedException(error);
  }
}
