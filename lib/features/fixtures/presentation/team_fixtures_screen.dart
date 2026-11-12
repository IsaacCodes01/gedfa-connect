import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/dashboard/data/team_home_providers.dart';
import 'package:gedfa_connect/features/dashboard/domain/team_home.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/team_home_widgets.dart';
import 'package:gedfa_connect/features/fixtures/data/cup_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/match_calendar.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/match_calendar_card.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/team_sheets/data/team_sheet_repository.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_status.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:go_router/go_router.dart';

/// Team: the Fixtures tab (3.0a, mockup F4). The next match in a blue card
/// with "Team sheet due in …", then what's coming, postponed, played and
/// cancelled. Tap a match for its details (F5, F6).
///
/// TDc (mockup TF1, TF2): a club in both competitions picks Division or
/// Juvenile (and an age group) with the same switch as Home, so the two
/// are never mixed; List | Calendar shows the month calendar instead.
class TeamFixturesScreen extends ConsumerStatefulWidget {
  const TeamFixturesScreen({super.key});

  @override
  ConsumerState<TeamFixturesScreen> createState() => _TeamFixturesScreenState();
}

class _TeamFixturesScreenState extends ConsumerState<TeamFixturesScreen> {
  // Moves matches from "coming up" to "played" and the countdown on
  late final Timer _clock;

  /// List (false) or Calendar (true), TDc
  bool _calendar = false;

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
    final sheets = ref.watch(myTeamSheetsProvider).value ?? const {};
    final view = ref.watch(matchViewProvider);
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
        loading: () => const SkeletonList(message: 'Loading your fixtures…'),
        error: (error, _) => ErrorView(
          message: appErrorMessage(error),
          onRetry: () => ref.invalidate(myFixturesProvider),
        ),
        data: (everything) {
          // TDc: only the competition (and age group) on the switch
          final all = team == null
              ? everything
              : view.filter(everything, team.categories);
          final groups = juvenileGroupsOf(everything);
          final shown = team == null
              ? Competition.division
              : view.shownFor(team.categories);
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

          if (everything.isEmpty) {
            return const EmptyView(
              icon: Icons.calendar_month_outlined,
              title: 'No matches yet',
              message: 'Your matches show here as soon as the FA adds them.',
            );
          }

          Widget row(Fixture f) {
            final home = f.isHome(teamId);
            final k = f.kickoffAt;
            // 3.1c: "Sheet saved", or "Sheet due Sat" within a week
            final sheet = SheetStatus.of(f, sheets[f.id], now);
            final due = sheet.due;
            return FixtureRow(
              fixture: f,
              extraTags: [
                if (sheet.state == SheetState.saved)
                  const FixtureTag('Sheet saved', tone: AccentTone.green)
                else if (sheet.state == SheetState.notStarted &&
                    due != null &&
                    due.difference(now).inDays < 7)
                  FixtureTag(
                    'Sheet due ${formatShortDate(due).substring(0, 3)}',
                    tone: AccentTone.gold,
                  ),
              ],
              dateLabel: k == null
                  ? 'New date to come · ${home ? 'Home' : 'Away'}'
                  : '${formatShortDate(k)} · ${home ? 'Home' : 'Away'}',
              onTap: () => context.push(Routes.teamMatch(f.id)),
            );
          }

          final next = coming.firstOrNull;
          int count(Competition c) =>
              everything.where((f) => f.category == c && !f.isCancelled).length;
          String matches(int n) => n == 1 ? '1 match' : '$n matches';

          final controls = <Widget>[
            if (team != null && team.hasBoth) ...[
              MatchSwitch(
                selected: shown,
                divisionNote: matches(count(Competition.division)),
                juvenileNote: [
                  matches(count(Competition.juvenile)),
                  for (final g in groups) g.label,
                ].join(' · '),
                onChanged: ref.read(matchViewProvider.notifier).setCompetition,
              ),
              if (shown == Competition.juvenile)
                AgeGroupChips(
                  groups: groups,
                  selected: view.ageGroup,
                  onChanged: ref.read(matchViewProvider.notifier).setAgeGroup,
                ),
              const SizedBox(height: 10),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.view_list_rounded),
                    label: Text('List'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.calendar_month_rounded),
                    label: Text('Calendar'),
                  ),
                ],
                selected: {_calendar},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _calendar = v.first),
              ),
            ),
            const SizedBox(height: 14),
          ];

          if (_calendar) {
            return ResponsiveCenter(
              maxWidth: 720,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  ...controls,
                  MatchCalendarCard(
                    key: ValueKey('${shown.name}-${view.ageGroup?.label}'),
                    fixtures: all,
                    teamId: teamId,
                    cups: {
                      for (final c
                          in ref.watch(seasonCupsProvider).value ?? const [])
                        c.id: c,
                    },
                    startMonth: startMonth(next, now),
                    onOpen: (f) => context.push(Routes.teamMatch(f.id)),
                  ),
                ],
              ),
            );
          }

          return ResponsiveCenter(
            maxWidth: 720,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                ...controls,
                if (all.isEmpty) NoMatchCard(anyMatches: everything.isNotEmpty),
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
                    sheet: sheets[next.id],
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
                  FixtureListCard(
                    children: [for (final f in postponed) row(f)],
                  ),
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
                  FixtureListCard(
                    children: [for (final f in cancelled) row(f)],
                  ),
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
    this.sheet,
  });

  final Fixture fixture;
  final String teamId;
  final DateTime now;
  final VoidCallback? onTap;

  /// My team's saved sheet for this match, if any (3.1c).
  final TeamSheet? sheet;

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
        mainAxisAlignment: end
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
                    _DueBox(fixtureId: f.id, due: due, now: now, sheet: sheet),
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

/// "Team sheet due in 2 h 14 min" in gold with "Make sheet"; once saved,
/// "Team sheet saved · 16 players" in green with "Change" (3.1c); after
/// the lock, "View" opens the sheet as saved.
class _DueBox extends StatelessWidget {
  const _DueBox({
    required this.fixtureId,
    required this.due,
    required this.now,
    required this.sheet,
  });

  final String fixtureId;
  final DateTime due;
  final DateTime now;
  final TeamSheet? sheet;

  /// "2 d 4 h", "2 h 14 min", "14 min"
  static String _left(Duration d) {
    if (d.inDays >= 1) return '${d.inDays} d ${d.inHours % 24} h';
    if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes.clamp(1, 59)} min';
  }

  @override
  Widget build(BuildContext context) {
    final closed = !due.isAfter(now);
    final saved = sheet;
    final colour = saved != null
        ? const Color(0xFF7BE0A4)
        : AppColors.ghanaGold;
    final soft = TextStyle(color: Colors.white.withValues(alpha: 0.8));
    final bold = TextStyle(color: colour, fontWeight: FontWeight.w700);
    final when = '${formatShortDate(due)}, ${formatTime(due)}';

    final List<InlineSpan> text = saved != null
        ? [
            TextSpan(text: closed ? 'Team sheet locked · ' : 'Team sheet '),
            TextSpan(
              text: closed ? '${saved.playerCount} players' : 'saved',
              style: bold,
            ),
            if (!closed) TextSpan(text: ' · ${saved.playerCount} players'),
            TextSpan(
              text: closed
                  ? '\nLocked $when, 1 hour before kick-off'
                  : '\nChange until $when',
              style: soft,
            ),
          ]
        : closed
        ? [
            const TextSpan(text: 'Team sheets closed at '),
            TextSpan(text: formatTime(due), style: bold),
            TextSpan(text: '\nNo sheet was saved', style: soft),
          ]
        : [
            const TextSpan(text: 'Team sheet due '),
            TextSpan(text: 'in ${_left(due.difference(now))}', style: bold),
            TextSpan(text: '\n$when, 1 hour before kick-off', style: soft),
          ];

    final String? action = saved != null
        ? (closed ? 'View' : 'Change')
        : (closed ? null : 'Make sheet');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.16),
        border: Border.all(color: colour.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            saved != null ? Icons.task_alt : Icons.assignment,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                children: text,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            Material(
              color: colour,
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => context.open(
                  Routes.teamSheet(fixtureId, check: action == 'View'),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    action,
                    style: const TextStyle(
                      color: Color(0xFF16261C),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
