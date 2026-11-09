import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/cup_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/postpone_plan.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/postpone_dialog.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:go_router/go_router.dart';

/// FA: Competitions (3.0c1, mockup C1), from the Fixtures tab. The two
/// leagues, then the season's cups and galas, each with what the FA does
/// next. Tapping a league goes back to the Fixtures tab on it; its ⋯
/// postpones it (3.0c1c, mockup C11).
class CompetitionsScreen extends ConsumerWidget {
  const CompetitionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixtures = ref.watch(seasonFixturesProvider).value ?? const [];
    final cupsAsync = ref.watch(seasonCupsProvider);

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Competitions',
        subtitle: 'Season ${Season.label(Season.current)}',
        leading: const BackButton(),
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            const DashboardSectionTitle(title: 'Leagues', top: 2),
            DashboardCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Row(
                    icon: Icons.format_list_numbered,
                    tone: AccentTone.blue,
                    title: 'Division League',
                    subtitle: _leagueLine(fixtures, Competition.division),
                    onTap: () => context.pop(Competition.division),
                    onMore: () => _leagueMenu(
                      context,
                      ref,
                      fixtures,
                      Competition.division,
                    ),
                  ),
                  const Divider(height: 1),
                  _Row(
                    icon: Icons.child_care,
                    tone: AccentTone.gold,
                    title: 'Juvenile League',
                    subtitle: _leagueLine(fixtures, Competition.juvenile),
                    onTap: () => context.pop(Competition.juvenile),
                    onMore: () => _leagueMenu(
                      context,
                      ref,
                      fixtures,
                      Competition.juvenile,
                    ),
                  ),
                ],
              ),
            ),
            const DashboardSectionTitle(title: 'Cups and Gala'),
            ...cupsAsync.when(
              loading: () => const [LoadingView()],
              error: (error, _) => [
                ErrorView(
                  message: appErrorMessage(error),
                  onRetry: () => ref.invalidate(seasonCupsProvider),
                ),
              ],
              data: (cups) => [
                if (cups.isEmpty)
                  const DashboardCard(
                    child: Text(
                      'No cups or Gala yet. Make one with the button below.',
                    ),
                  )
                else
                  DashboardCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, cup) in cups.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          _cupRow(context, cup),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'The tag says what the FA does next: draw the next round, '
                  'or mark who went through.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push(Routes.adminNewCup),
              icon: const Icon(Icons.add),
              label: const Text('New cup or Gala'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cupRow(BuildContext context, Cup cup) {
    final (icon, tone) = switch (cup) {
      Cup(isGala: true) => (Icons.stadium, AccentTone.green),
      Cup(who: CupWho.open) => (Icons.public, AccentTone.blue),
      Cup(who: CupWho.juvenile) => (Icons.sports_soccer, AccentTone.violet),
      _ => (Icons.emoji_events, AccentTone.gold),
    };
    final parts = [
      if (cup.who == CupWho.open)
        'Open · Division and ${cup.ageGroup?.label ?? 'juvenile'} sides'
      else
        cup.kind.label,
      '${cup.entries.length} teams',
      if (cup.gala case final gala?) gala.ground,
      'not drawn yet',
    ];
    return _Row(
      icon: icon,
      tone: tone,
      title: cup.name,
      subtitle: parts.join(' · '),
      tag: 'Draw',
      // The cup's page (3.0c1b, C7)
      onTap: () => context.push(Routes.adminCup(cup.id)),
    );
  }

  /// "18 teams · home and away · matchday 4 of 34", or for juvenile
  /// "U13 · U15 · U17 · 12 clubs".
  static String _leagueLine(List<Fixture> all, Competition category) {
    final league = [
      for (final f in all)
        if (f.competitionId == Fixture.leagueId(Season.current, category) &&
            !f.isCancelled)
          f,
    ];
    if (league.isEmpty) return 'No matches yet · Make the season';
    final teams = {
      for (final f in league) ...[f.home.id, f.away.id],
    };
    if (category == Competition.juvenile) {
      return '${Competition.juvenileAgeGroups.join(' · ')} · '
          '${teams.length} clubs';
    }
    final pairs = {for (final f in league) '${f.home.id}>${f.away.id}'};
    final twice = league.any(
      (f) => pairs.contains('${f.away.id}>${f.home.id}'),
    );
    final last = league.map((f) => f.round).reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();
    final coming = [
      for (final f in league)
        if (!f.isPlayed(now)) f.round,
    ];
    final next = coming.isEmpty ? null : coming.reduce((a, b) => a < b ? a : b);
    // Before anything is played: when it starts (C11)
    final start = league.any((f) => f.isPlayed(now))
        ? null
        : PostponePlan.of(league, now)?.first.kickoffAt;
    return [
      '${teams.length} teams',
      if (twice) 'home and away',
      if (start != null)
        'starts ${formatShortDate(start)}'
      else if (next == null)
        'all $last matchdays played'
      else
        'matchday $next of $last',
    ].join(' · ');
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tag,
    this.onMore,
  });

  final IconData icon;
  final AccentTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// What the FA does next, e.g. "Draw"; null shows an arrow.
  final String? tag;

  /// The ⋯ on a league (C11); shown instead of the arrow.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AccentIcon(icon: icon, tone: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onMore != null)
              IconButton(
                tooltip: 'More',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                onPressed: onMore,
              )
            else if (tag case final tag?)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AccentTone.gold.background(isDark),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AccentTone.gold.foreground(isDark),
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// The ⋯ on a league (C11): Postpone, while matches are left to play.
void _leagueMenu(
  BuildContext context,
  WidgetRef ref,
  List<Fixture> all,
  Competition category,
) {
  final league = [
    for (final f in all)
      if (f.competitionId == Fixture.leagueId(Season.current, category)) f,
  ];
  final plan = PostponePlan.of(league, DateTime.now());
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListTile(
        leading: const Icon(Icons.event_repeat),
        title: const Text(
          'Postpone',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          plan == null
              ? 'No matches left to move'
              : 'Every matchday not played yet moves; the clubs are told',
        ),
        enabled: plan != null,
        onTap: () {
          Navigator.pop(sheet);
          if (plan != null) _postponeLeague(context, ref, category, plan);
        },
      ),
    ),
  );
}

/// "Postpone the Division League?" (C11), then every match not played
/// yet moves, with a progress bar. If the connection drops, Try again
/// carries on with the same plan where it stopped.
Future<void> _postponeLeague(
  BuildContext context,
  WidgetRef ref,
  Competition category,
  PostponePlan plan,
) async {
  final name = '${category.label} League';
  final clubs = {
    for (final f in plan.moving) ...[f.home.id, f.away.id],
  };
  final choice = await showPostponeDialog(
    context,
    title: 'Postpone the $name?',
    message:
        'Every matchday not played yet moves by the same number of days, '
        'weeks off included. All ${clubs.length} clubs are told.',
    fieldLabel: 'Matchday ${plan.first.round}',
    from: plan.first.kickoffAt!,
    lastFrom: plan.last.kickoffAt!,
    lastWhat: 'The last matchday',
  );
  if (choice == null || !context.mounted) return;
  final me = ref.read(authRepositoryProvider).currentUser;
  if (me == null) return;

  final moved = plan.movedTo(choice.newDay);
  final repository = ref.read(fixtureRepositoryProvider);
  final navigator = Navigator.of(context, rootNavigator: true);
  final progress = ValueNotifier<(int, int)>((0, moved.moving.length));
  try {
    while (true) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Postponing…'),
            content: ValueListenableBuilder<(int, int)>(
              valueListenable: progress,
              builder: (_, p, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: p.$2 == 0 ? null : p.$1 / p.$2,
                  ),
                  const SizedBox(height: 10),
                  Text('${p.$1} of ${p.$2} matches'),
                ],
              ),
            ),
          ),
        ),
      );
      try {
        await repository.postponeMatches(
          moved,
          competitionName: name,
          reason: choice.reason,
          by: me,
          onProgress: (done, total) => progress.value = (done, total),
        );
        navigator.pop(); // the progress
        if (context.mounted) {
          AppToast.success(
            context,
            '$name postponed ${laterLabel(moved.days)}. Every club was told.',
          );
        }
        return;
      } catch (error) {
        navigator.pop();
        if (!context.mounted) return;
        final (done, total) = progress.value;
        final again = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('It stopped at $done of $total'),
            content: Text(
              '${appErrorMessage(error)} The matches already moved stay '
              'moved. Try again: it carries on where it stopped.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Stop'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Try again'),
              ),
            ],
          ),
        );
        if (again != true) return;
      }
    }
  } finally {
    progress.dispose();
  }
}
