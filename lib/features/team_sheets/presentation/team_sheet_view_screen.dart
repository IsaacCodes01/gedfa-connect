import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/team_sheets/data/team_sheet_repository.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_roles.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/widgets/sheet_check_step.dart';

/// One team's sheet, read only (3.2): the FA any time, the other team from
/// the lock (1 hour before kick-off). The same sheet as the Check step
/// (MS5), drawn from the copies saved on it, so nobody reads the club's
/// player files.
class TeamSheetViewScreen extends ConsumerWidget {
  const TeamSheetViewScreen({
    super.key,
    required this.fixtureId,
    required this.teamId,
    required this.isFa,
  });

  final String fixtureId;
  final String teamId;
  final bool isFa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixture = ref.watch(fixtureProvider(fixtureId));
    final sheet = ref.watch(teamSheetProvider((fixtureId, teamId)));
    final f = fixture.value;
    final s = sheet.value;
    final side = f == null ? null : (f.home.id == teamId ? f.home : f.away);

    Widget body;
    final error = fixture.error ?? sheet.error;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (fixture.isLoading || sheet.isLoading) {
      body = const LoadingView();
    } else if (f == null || s == null || side == null) {
      body = EmptyView(
        icon: Icons.assignment_outlined,
        title: 'No team sheet',
        message: isFa
            ? 'This team has not saved a sheet for this match yet.'
            : 'It shows here from 1 hour before kick-off, once the team '
                  'has saved it.',
      );
    } else {
      final due = f.sheetDueAt;
      final savedAt = s.savedAt;
      final locked = due == null || !DateTime.now().isBefore(due);
      body = ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                savedSheetPaper(f, s),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Icon(
                        locked ? Icons.lock_outline : Icons.edit_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            if (savedAt != null)
                              'Saved ${formatShortDate(savedAt)}, '
                                  '${formatTime(savedAt)}',
                            if (locked)
                              'locked'
                            else
                              'the team can change it until '
                                  '${formatShortDate(due)}, ${formatTime(due)}',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!locked)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _Note(
                      'The other team sees this sheet from the lock, 1 hour '
                      'before kick-off.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Team sheet',
        subtitle: side?.name,
        leading: AppBackButton(
          fallback: isFa
              ? Routes.adminMatch(fixtureId)
              : Routes.teamMatch(fixtureId),
        ),
      ),
      body: body,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccentTone.blue.background(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12.5)),
    );
  }
}

/// A saved sheet drawn as paper (MS5): the read-only view (3.2) and the
/// officials' Match details from the lock (3.5c, [showIds]: MC1). Drawn
/// from the copies on the sheet, so nobody reads the club's player files.
Widget savedSheetPaper(Fixture f, TeamSheet s, {bool showIds = false}) {
  SheetPlayer line(String id) =>
      s.players[id] ??
      // Saved before 3.2, without copies: the shirt number only
      SheetPlayer(
        id: id,
        name: 'Player (saved before names were copied)',
        position: '',
        usual: s.numbers[id] ?? 0,
      );
  final side = f.home.id == s.teamId ? f.home : f.away;
  final kickoff = f.kickoffAt;
  return SheetPaper(
    title: side.name,
    subtitle: [
      'v ${f.opponentOf(s.teamId).name}',
      f.competitionLabel,
      if (kickoff != null)
        '${formatShortDate(kickoff)}, ${formatTime(kickoff)}',
      f.venue,
    ].join(' · '),
    kit: f.kitOf(s.teamId).kit,
    starters: [for (final id in s.starters) line(id)],
    bench: [for (final id in s.bench) line(id)],
    maxBench: 7,
    numbers: s.numbers,
    roles: SheetRoles(
      captainId: s.captainId,
      viceCaptainId: s.viceCaptainId,
      goalkeeperId: s.goalkeeperId,
    ),
    officials: s.officials,
    matchGroup: f.ageGroup,
    showIds: showIds,
  );
}
