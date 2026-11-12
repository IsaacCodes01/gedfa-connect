import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/sending.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/cup_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/postpone_job.dart';
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
    // Postpones that stopped (3.0c1d, C13)
    final jobs = ref.watch(postponeJobsProvider).value ?? const {};
    PostponeJob? jobOf(Competition category) =>
        jobs[Fixture.leagueId(Season.current, category)];

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
            for (final job in jobs.values) ...[
              _StoppedCard(job: job),
              const SizedBox(height: 4),
            ],
            DashboardSectionTitle(title: 'Leagues', top: jobs.isEmpty ? 2 : 20),
            DashboardCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Row(
                    icon: Icons.format_list_numbered,
                    tone: AccentTone.blue,
                    title: 'Division League',
                    subtitle: _leagueLine(
                      fixtures,
                      Competition.division,
                      jobOf(Competition.division),
                    ),
                    onTap: () => context.pop(Competition.division),
                    onMore: () => _leagueMenu(
                      context,
                      ref,
                      fixtures,
                      Competition.division,
                      jobOf(Competition.division),
                    ),
                  ),
                  const Divider(height: 1),
                  _Row(
                    icon: Icons.child_care,
                    tone: AccentTone.gold,
                    title: 'Juvenile League',
                    subtitle: _leagueLine(
                      fixtures,
                      Competition.juvenile,
                      jobOf(Competition.juvenile),
                    ),
                    onTap: () => context.pop(Competition.juvenile),
                    onMore: () => _leagueMenu(
                      context,
                      ref,
                      fixtures,
                      Competition.juvenile,
                      jobOf(Competition.juvenile),
                    ),
                  ),
                ],
              ),
            ),
            const DashboardSectionTitle(title: 'Cups and Gala'),
            ...cupsAsync.when(
              loading: () => const [LoadingView(message: 'Loading competitions…')],
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
  /// "U13 · U15 · U17 · 12 clubs"; while a postpone is unfinished,
  /// "postponing: 42 of 306 moved" (C13).
  static String _leagueLine(
    List<Fixture> all,
    Competition category,
    PostponeJob? job,
  ) {
    final postponing = job == null
        ? null
        : 'postponing: ${job.movedCount} of ${job.moves.length} moved';
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
      return [
        ...Competition.juvenileAgeGroups,
        '${teams.length} clubs',
        ?postponing,
      ].join(' · ');
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
      if (postponing != null)
        postponing
      else if (start != null)
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

/// The ⋯ on a league (C11): Postpone, while matches are left to play and
/// no postpone of it is unfinished (C14).
void _leagueMenu(
  BuildContext context,
  WidgetRef ref,
  List<Fixture> all,
  Competition category,
  PostponeJob? job,
) {
  final league = [
    for (final f in all)
      if (f.competitionId == Fixture.leagueId(Season.current, category)) f,
  ];
  final plan = job == null ? PostponePlan.of(league, DateTime.now()) : null;
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
          job != null
              ? 'Finish the postpone that stopped first'
              : plan == null
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

/// "Postpone the Division League?" (C11): the job is saved first (3.0c1d),
/// then the matches move.
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
  final PostponeJob job;
  try {
    job = await ref
        .read(fixtureRepositoryProvider)
        .startPostpone(
          plan.movedTo(choice.newDay),
          competitionName: name,
          reason: choice.reason,
          by: me,
        );
  } catch (error) {
    if (context.mounted) AppToast.error(context, appErrorMessage(error));
    return;
  }
  if (context.mounted) await _runPostpone(context, ref, job, starting: true);
}

/// Moves the matches of [job] not moved yet, with a progress bar
/// ("Postponing…", or "Finishing…" from Finish, C15). If it stops: Try
/// again now, or Later from Competitions (C12). Nothing moves twice.
Future<void> _runPostpone(
  BuildContext context,
  WidgetRef ref,
  PostponeJob job, {
  bool starting = false,
}) async {
  final me = ref.read(authRepositoryProvider).currentUser;
  if (me == null) return;
  final repository = ref.read(fixtureRepositoryProvider);
  final progress = ValueNotifier<(int, int)>((
    job.movedCount,
    job.moves.length,
  ));
  var current = job;
  try {
    while (true) {
      if (!context.mounted) return;
      try {
        // S2 (M2): the sheet with the progress bar
        await SendingSheet.run(
          context,
          title: starting ? 'Postponing…' : 'Finishing…',
          unit: 'Match',
          start: SendingProgress(progress.value.$1, progress.value.$2),
          task: (onProgress) => repository.finishPostpone(
            current,
            by: me,
            onProgress: (done, total) {
              progress.value = (done, total);
              onProgress(done, total);
            },
          ),
        );
        if (context.mounted) {
          AppToast.success(
            context,
            '${job.name} postponed ${laterLabel(job.days)}. Every club was '
            'told.',
          );
        }
        return;
      } catch (error) {
        if (!context.mounted) return;
        final (done, total) = progress.value;
        final again = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('It stopped at $done of $total'),
            content: Text(
              '${appErrorMessage(error)} The $done matches already moved stay '
              'moved. Try again now, or finish it later from Competitions '
              '(on any phone or laptop): nothing moves twice.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Try again'),
              ),
            ],
          ),
        );
        if (again != true) return;
        // The job as saved now: what is already ticked off
        current =
            ref.read(postponeJobsProvider).value?[job.competitionId] ?? current;
      }
    }
  } finally {
    progress.dispose();
  }
}

/// "Division League: postponing stopped", with Finish (3.0c1d, C13).
class _StoppedCard extends ConsumerWidget {
  const _StoppedCard({required this.job});

  final PostponeJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AccentTone.gold.foreground(isDark);
    final total = job.moves.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AccentTone.gold.background(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0A800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.event_repeat, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${job.name}: postponing stopped',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${job.movedCount} of $total matches moved '
                      '${laterLabel(job.days)}. The rest still have their '
                      "old dates, and the clubs aren't told yet.",
                      style: TextStyle(fontSize: 12, color: fg),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : job.movedCount / total,
                        minHeight: 6,
                        color: fg,
                        backgroundColor: fg.withValues(alpha: 0.18),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'Started by ${job.byName}',
                        if (job.startedAt case final at?)
                          '${formatShortDate(at)}, ${formatTime(at)}',
                        '"${job.reason}"',
                      ].join(' · '),
                      style: TextStyle(fontSize: 11.5, color: fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _runPostpone(context, ref, job),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}
