import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/cup_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:go_router/go_router.dart';

/// FA: Competitions (3.0c1, mockup C1), from the Fixtures tab. The two
/// leagues, then the season's cups and galas, each with what the FA does
/// next. Tapping a league goes back to the Fixtures tab on it.
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
                  ),
                  const Divider(height: 1),
                  _Row(
                    icon: Icons.child_care,
                    tone: AccentTone.gold,
                    title: 'Juvenile League',
                    subtitle: _leagueLine(fixtures, Competition.juvenile),
                    onTap: () => context.pop(Competition.juvenile),
                  ),
                ],
              ),
            ),
            const DashboardSectionTitle(title: 'Cups and galas'),
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
                      'No cups or galas yet. Make one with the button below.',
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
              label: const Text('New cup or gala'),
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
      // The live draw is the next step (3.0c2)
      onTap: () => AppToast.info(context, 'The live draw comes next.'),
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
    final teams = {for (final f in league) ...[f.home.id, f.away.id]};
    if (category == Competition.juvenile) {
      return '${Competition.juvenileAgeGroups.join(' · ')} · '
          '${teams.length} clubs';
    }
    final pairs = {for (final f in league) '${f.home.id}>${f.away.id}'};
    final twice = league.any((f) => pairs.contains('${f.away.id}>${f.home.id}'));
    final last = league.map((f) => f.round).reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();
    final coming = [
      for (final f in league)
        if (!f.isPlayed(now)) f.round,
    ];
    final next = coming.isEmpty ? null : coming.reduce((a, b) => a < b ? a : b);
    return [
      '${teams.length} teams',
      if (twice) 'home and away',
      next == null ? 'all $last matchdays played' : 'matchday $next of $last',
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
  });

  final IconData icon;
  final AccentTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// What the FA does next, e.g. "Draw"; null shows an arrow.
  final String? tag;

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
            if (tag case final tag?)
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
