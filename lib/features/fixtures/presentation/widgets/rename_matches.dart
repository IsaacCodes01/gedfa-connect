import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
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
  final navigator = Navigator.of(context, rootNavigator: true);
  final progress = ValueNotifier<(int, int)>((0, 0));

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Renaming matches…'),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (_, p, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$newName is approved. Its matches are being renamed.'),
              const SizedBox(height: 14),
              LinearProgressIndicator(value: p.$2 == 0 ? null : p.$1 / p.$2),
              const SizedBox(height: 8),
              Text(
                p.$2 == 0
                    ? 'Finding its matches…'
                    : '${p.$1} of ${p.$2} · keep the app open',
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await ref
        .read(fixtureRepositoryProvider)
        .renameTeam(
          teamId,
          until: until ?? DateTime.now(),
          by: me,
          onProgress: (done, total) => progress.value = (done, total),
        );
  } catch (error) {
    throw RenameStoppedException(error);
  } finally {
    navigator.pop();
    progress.dispose();
  }
}
