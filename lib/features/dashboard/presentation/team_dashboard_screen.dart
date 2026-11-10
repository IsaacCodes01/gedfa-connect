import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/dashboard/data/team_home_providers.dart';
import 'package:gedfa_connect/features/dashboard/domain/team_home.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/team_home_widgets.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/suspension_widgets.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/payments/data/payment_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';
import 'package:gedfa_connect/features/teams/data/correction_request_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/correction_request.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

/// Team: the Home tab, the first screen after signing in (TDa, mockup
/// td-team-dashboard TD1–TD3). The blue header, the Division | Juvenile
/// switch (clubs in both), the next match and the 2 after it, then
/// "Needs you". Everything is live from what the team app already reads.
class TeamDashboardScreen extends ConsumerStatefulWidget {
  const TeamDashboardScreen({super.key});

  @override
  ConsumerState<TeamDashboardScreen> createState() =>
      _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends ConsumerState<TeamDashboardScreen> {
  // Moves "in 4 days" on, and a played match off the card
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
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
    final teamAsync = ref.watch(myTeamProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons over the blue header
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: teamAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: appErrorMessage(error),
            onRetry: () => ref.invalidate(myTeamProvider),
          ),
          data: (team) => team == null
              ? const EmptyView(
                  icon: Icons.shield_outlined,
                  title: 'No team linked',
                  message:
                      'Your account is not linked to a team yet. '
                      'Please contact the FA.',
                )
              : _body(team),
        ),
      ),
    );
  }

  Widget _body(Team team) {
    final now = DateTime.now();
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final fixtures = ref.watch(myFixturesProvider).value ?? const <Fixture>[];
    final settings = ref.watch(leagueSettingsProvider).value;
    final view = ref.watch(matchViewProvider);
    final groups = juvenileGroupsOf(fixtures);
    final shown = view.shownFor(team.categories);
    final upcoming = UpcomingMatches.of(
      view.filter(fixtures, team.categories),
      now,
    );
    final suspension = team.isSuspended ? team.suspension : null;
    final registrationOpen = settings?.playerRegistrationOpen ?? true;

    int matchesIn(Competition c) =>
        fixtures.where((f) => f.category == c && !f.isCancelled).length;
    String matchCount(int n) => n == 1 ? '1 match' : '$n matches';

    final header = DashboardHeader(
      wide: wide,
      label: 'GEDFA CONNECT · TEAM',
      crest: TeamLogo(
        label: team.shortName.isNotEmpty
            ? team.shortName
            : initialsFor(team.name),
        color: team.logoColor,
        url: team.logoUrl,
        size: 52,
      ),
      subtitle: '${team.name} · ${formatShortDate(now)}',
      tags: [
        suspension == null
            ? const HeaderTag(open: true, label: 'Approved')
            : const HeaderTag(open: false, label: 'Suspended'),
        HeaderTag(
          label: [
            if (team.categories.contains(Competition.division)) 'Division',
            if (team.categories.contains(Competition.juvenile))
              for (final g in groups) g.label,
          ].join(' · '),
        ),
        HeaderTag(
          label: 'Season ${Season.label(settings?.season ?? Season.current)}',
        ),
        if (suspension == null)
          HeaderTag(
            open: registrationOpen,
            label: registrationOpen
                ? 'Player registration open'
                : 'Player registration closed',
          ),
      ],
    );

    final next = upcoming.next;
    final needs = _needRows(team, groups);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        header,
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: wide
                  ? const EdgeInsets.fromLTRB(28, 22, 28, 30)
                  : const EdgeInsets.fromLTRB(14, 16, 14, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Suspended by the chairman (2.11c, TD3)
                  if (suspension != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SuspendedBanner(
                        title: 'Your team is suspended',
                        suspension: suspension,
                        message:
                            "You can't add players or play matches until "
                            'the chairman lifts it.',
                      ),
                    ),
                  if (team.hasBoth) ...[
                    MatchSwitch(
                      selected: shown,
                      divisionNote: matchCount(matchesIn(Competition.division)),
                      juvenileNote: [
                        matchCount(matchesIn(Competition.juvenile)),
                        for (final g in groups) g.label,
                      ].join(' · '),
                      onChanged: ref
                          .read(matchViewProvider.notifier)
                          .setCompetition,
                    ),
                    if (shown == Competition.juvenile)
                      AgeGroupChips(
                        groups: groups,
                        selected: view.ageGroup,
                        onChanged: ref
                            .read(matchViewProvider.notifier)
                            .setAgeGroup,
                      ),
                  ],
                  DashboardSectionTitle(
                    title: 'Next match',
                    trailing: 'All fixtures ›',
                    onTap: () => context.open(Routes.teamFixtures),
                    top: team.hasBoth || suspension != null ? 18 : 2,
                  ),
                  if (next == null)
                    NoMatchCard(anyMatches: fixtures.isNotEmpty)
                  else
                    HomeNextMatchCard(
                      fixture: next,
                      teamId: team.id,
                      now: now,
                      onDetails: () => context.open(Routes.teamMatch(next.id)),
                      onKits: () =>
                          context.open(Routes.teamFixtureKits(next.id)),
                    ),
                  if (upcoming.comingUp.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ComingUpCard(
                      fixtures: upcoming.comingUp,
                      teamId: team.id,
                      onTap: (f) => context.open(Routes.teamMatch(f.id)),
                    ),
                  ],
                  DashboardSectionTitle(
                    title: 'Needs you',
                    trailing: needs.isEmpty ? null : '${needs.length} to do',
                  ),
                  if (needs.isEmpty)
                    const TeamCaughtUpCard()
                  else
                    TeamNeedsCard(rows: needs),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "Needs you" in words, from [teamNeeds].
  List<TeamNeedRow> _needRows(Team team, List<AgeGroup> groups) {
    final players = ref.watch(teamPlayersProvider).value ?? const [];
    final settings = ref.watch(leagueSettingsProvider).value;
    final correction = ref.watch(myCorrectionRequestProvider).value;
    final screening = ref.watch(upcomingScreeningsProvider).value?.firstOrNull;
    final requestUid = team.requestUid;
    final fee = requestUid == null
        ? null
        : ref.watch(feeSummaryProvider(requestUid)).value;
    final asked = correction?.status == CorrectionStatus.asked;

    final needs = teamNeeds(
      categories: team.categories,
      players: players,
      juvenileGroups: groups,
      correctionAsked: asked,
      screeningPlanned: screening != null,
      feeLeft: fee?.left ?? 0,
      feeStarted: fee?.hasStarted ?? true,
      matchdaySquad: settings?.matchdaySquad ?? 18,
      minPlayers: settings?.minPlayers ?? 7,
    );

    void open(String route) => context.open(route);

    return [
      for (final need in needs)
        switch (need.kind) {
          TeamNeedKind.playersSentBack => TeamNeedRow(
            icon: Icons.undo_rounded,
            tone: AccentTone.red,
            label: need.count == 1
                ? '1 player sent back'
                : '${need.count} players sent back',
            detail:
                '${need.names.join(', ')}'
                '${need.count > need.names.length ? '…' : ''}'
                ' · fix and send again',
            count: need.count,
            onTap: () => open(Routes.team),
          ),
          TeamNeedKind.correctionAsked => TeamNeedRow(
            icon: Icons.edit_note_rounded,
            tone: AccentTone.gold,
            label: 'The FA asked you to correct',
            detail: [
              correction!.itemsText,
              if (correction.askedAt case final at?)
                'asked ${formatDayMonth(at)}',
            ].join(' · '),
            onTap: () => open(Routes.team),
          ),
          TeamNeedKind.screening => TeamNeedRow(
            icon: Icons.child_care_rounded,
            tone: AccentTone.violet,
            label: 'Screening day ${screening!.dateText}',
            detail:
                '${need.count == 1 ? '1 child' : '${need.count} children'} '
                'waiting · ${screening.venue}',
            onTap: () => open(Routes.team),
          ),
          TeamNeedKind.feeOwed => TeamNeedRow(
            icon: Icons.payments_rounded,
            tone: need.urgent ? AccentTone.red : AccentTone.gold,
            label: 'Season fee: ${cedis(need.count)} left',
            detail: fee == null || !fee.hasStarted
                ? 'Nothing paid yet'
                : '${cedis(fee.confirmed)} of ${cedis(fee.fee)} paid',
            onTap: () => open(Routes.teamFee),
          ),
          TeamNeedKind.squadShort => _squadRow(need),
        },
    ];
  }

  /// "Add 2 more for a full squad" (blue), or "Can't play yet" (red) with
  /// fewer than `minPlayers`. Juvenile rows start with the age group.
  TeamNeedRow _squadRow(TeamNeed need) {
    final r = need.readiness!;
    final group = need.ageGroup?.label;
    String withGroup(String text) => group == null
        ? text
        : '$group: ${text[0].toLowerCase()}${text.substring(1)}';
    return r.canPlay
        ? TeamNeedRow(
            icon: Icons.group_add_rounded,
            tone: AccentTone.blue,
            label: withGroup('Add ${r.missing} more for a full squad'),
            detail:
                '${r.approved} approved · you can play (${r.minimum} '
                'needed) · full squad is ${r.full}',
            onTap: () => context.open(Routes.team),
          )
        : TeamNeedRow(
            icon: Icons.group_off_rounded,
            tone: AccentTone.red,
            label: withGroup(
              "Can't play yet: at least ${r.minimum} approved players",
            ),
            detail:
                '${r.approved} approved · add ${r.missingToPlay} more to '
                'play · full squad is ${r.full}',
            onTap: () => context.open(Routes.team),
          );
  }
}
