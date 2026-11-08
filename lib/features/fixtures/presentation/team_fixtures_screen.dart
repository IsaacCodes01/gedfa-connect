import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:go_router/go_router.dart';

/// Team: the Fixtures tab (3.0a, mockup F4). The next match in a blue card
/// with "Team sheet due in …", then what's coming, postponed, played and
/// cancelled. Tap a match for its details (F5, F6).
class TeamFixturesScreen extends ConsumerStatefulWidget {
  const TeamFixturesScreen({super.key});

  @override
  ConsumerState<TeamFixturesScreen> createState() => _TeamFixturesScreenState();
}

class _TeamFixturesScreenState extends ConsumerState<TeamFixturesScreen> {
  // Moves matches from "coming up" to "played" and the countdown on
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(appUserProvider).value?.teamId ?? '';
    final team = ref.watch(myTeamProvider).value;
    final fixturesAsync = ref.watch(myFixturesProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Fixtures',
        subtitle: team == null
            ? null
            : '${team.name} · ${team.categories.map((c) => c.label).join(' and ')}',
        actions: const [NotificationBell()],
      ),
      body: fixturesAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: appErrorMessage(error),
          onRetry: () => ref.invalidate(myFixturesProvider),
        ),
        data: (all) {
          // Still on (kicked off less than 2 hours ago) counts as coming
          final coming = [
            for (final f in all)
              if (f.isScheduled && !f.isPlayed(now)) f,
          ]..sort((a, b) => a.kickoffAt!.compareTo(b.kickoffAt!));
          final played = [
            for (final f in all)
              if (f.isPlayed(now)) f,
          ]..sort((a, b) => b.kickoffAt!.compareTo(a.kickoffAt!));
          final postponed = all.where((f) => f.isPostponed).toList();
          final cancelled = all.where((f) => f.isCancelled).toList();

          if (all.isEmpty) {
            return const EmptyView(
              icon: Icons.calendar_month_outlined,
              title: 'No matches yet',
              message: 'Your matches show here as soon as the FA adds them.',
            );
          }

          Widget row(Fixture f) {
            final home = f.isHome(teamId);
            final k = f.kickoffAt;
            return FixtureRow(
              fixture: f,
              dateLabel: k == null
                  ? 'New date to come · ${home ? 'Home' : 'Away'}'
                  : '${formatShortDate(k)} · ${home ? 'Home' : 'Away'}',
              onTap: () => context.push(Routes.teamMatch(f.id)),
            );
          }

          final next = coming.firstOrNull;
          return ResponsiveCenter(
            maxWidth: 720,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                if (next != null) ...[
                  DashboardSectionTitle(
                    title: 'Next match',
                    trailing: next.ageGroup == null
                        ? 'Matchday ${next.round}'
                        : '${next.ageGroup!.label} · Matchday ${next.round}',
                    top: 2,
                  ),
                  NextMatchCard(
                    fixture: next,
                    teamId: teamId,
                    now: now,
                    onTap: () => context.push(Routes.teamMatch(next.id)),
                  ),
                ],
                if (coming.length > 1) ...[
                  const DashboardSectionTitle(title: 'Coming up'),
                  FixtureListCard(
                    children: [for (final f in coming.skip(1)) row(f)],
                  ),
                ],
                if (postponed.isNotEmpty) ...[
                  const DashboardSectionTitle(title: 'Postponed'),
                  FixtureListCard(children: [for (final f in postponed) row(f)]),
                ],
                if (played.isNotEmpty) ...[
                  const DashboardSectionTitle(
                    title: 'Played',
                    trailing: 'Results come in Phase 4',
                  ),
                  FixtureListCard(children: [for (final f in played) row(f)]),
                ],
                if (cancelled.isNotEmpty) ...[
                  const DashboardSectionTitle(title: 'Cancelled'),
                  FixtureListCard(children: [for (final f in cancelled) row(f)]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The team's next match (mockup F4): a deep blue card with both crests,
/// the kick-off, the ground, the kit to wear and the team sheet countdown.
class NextMatchCard extends StatelessWidget {
  const NextMatchCard({
    super.key,
    required this.fixture,
    required this.teamId,
    required this.now,
    this.onTap,
  });

  final Fixture fixture;
  final String teamId;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kickoff = f.kickoffAt!;
    final due = f.sheetDueAt!;
    final home = f.isHome(teamId);
    const white = TextStyle(color: Colors.white);

    Widget side(FixtureSide s, {bool end = false}) {
      final name = Flexible(
        child: Text(
          s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: end ? TextAlign.end : TextAlign.start,
          style: white.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      );
      return Row(
        mainAxisAlignment:
            end ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: end
            ? [name, const SizedBox(width: 8), FixtureCrest(side: s)]
            : [FixtureCrest(side: s), const SizedBox(width: 8), name],
      );
    }

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? AppColors.darkHeroGradient
                  : AppColors.heroGradient,
              stops: const [0, 0.55, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 24,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatShortDate(kickoff).toUpperCase()} · '
                      '${home ? 'HOME' : 'AWAY'}',
                      style: white.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: side(f.home)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            formatTime(kickoff),
                            style: white.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: side(f.away, end: true)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _Meta(icon: Icons.location_on_outlined, text: f.venue),
                        _Meta(
                          icon: Icons.checkroom_outlined,
                          text: f.kitOf(teamId).slot.label,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DueBox(due: due, now: now),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Colors.white.withValues(alpha: 0.85);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 4),
        // A long ground name ends in "…" on a phone
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// "Team sheet due in 2 h 14 min" in gold, with "Make sheet" (3.1).
class _DueBox extends StatelessWidget {
  const _DueBox({required this.due, required this.now});

  final DateTime due;
  final DateTime now;

  /// "2 d 4 h", "2 h 14 min", "14 min"
  static String _left(Duration d) {
    if (d.inDays >= 1) return '${d.inDays} d ${d.inHours % 24} h';
    if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes.clamp(1, 59)} min';
  }

  @override
  Widget build(BuildContext context) {
    final closed = !due.isAfter(now);
    const gold = AppColors.ghanaGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.16),
        border: Border.all(color: gold.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                children: closed
                    ? [
                        const TextSpan(text: 'Team sheets closed at '),
                        TextSpan(
                          text: formatTime(due),
                          style: const TextStyle(
                            color: gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]
                    : [
                        const TextSpan(text: 'Team sheet due '),
                        TextSpan(
                          text: 'in ${_left(due.difference(now))}',
                          style: const TextStyle(
                            color: gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '\n${formatShortDate(due)}, '
                              '${formatTime(due)}, 1 hour before kick-off',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Team sheets are step 3.1
          Material(
            color: gold.withValues(alpha: closed ? 0.4 : 1),
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () => AppToast.info(
                context,
                'Making the team sheet comes in the next update (3.1).',
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'Make sheet',
                  style: TextStyle(
                    color: Color(0xFF3A2C00),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
