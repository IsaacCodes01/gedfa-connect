import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/season_stats_card.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/team_home_cards.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
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
import 'package:gedfa_connect/features/fixtures/data/cup_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/match_calendar.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/match_calendar_card.dart';
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
    final waiting = _waitingRows(team);
    final shownMatches = view.filter(fixtures, team.categories);

    // TDc: the month calendar (phone: under Coming up; laptop: on the
    // right). A new switch choice opens it again on its next match.
    final calendar = [
      DashboardSectionTitle(
        title: 'Match calendar',
        trailing: 'Fixtures ›',
        onTap: () => context.open(Routes.teamFixtures),
        top: wide ? 26 : 20,
      ),
      MatchCalendarCard(
        key: ValueKey('${shown.name}-${view.ageGroup?.label}'),
        fixtures: shownMatches,
        teamId: team.id,
        cups: {
          for (final c in ref.watch(seasonCupsProvider).value ?? const [])
            c.id: c,
        },
        startMonth: startMonth(next, now),
        onOpen: (f) => context.open(Routes.teamMatch(f.id)),
      ),
    ];

    final matches = <Widget>[
      if (team.hasBoth) ...[
        MatchSwitch(
          selected: shown,
          divisionNote: matchCount(matchesIn(Competition.division)),
          juvenileNote: [
            matchCount(matchesIn(Competition.juvenile)),
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
      ],
      DashboardSectionTitle(
        title: 'Next match',
        trailing: 'All fixtures ›',
        onTap: () => context.open(Routes.teamFixtures),
        top: team.hasBoth ? 18 : (wide ? 26 : 2),
      ),
      if (next == null)
        NoMatchCard(anyMatches: fixtures.isNotEmpty)
      else
        HomeNextMatchCard(
          fixture: next,
          teamId: team.id,
          now: now,
          onDetails: () => context.open(Routes.teamMatch(next.id)),
          onKits: () => context.open(Routes.teamFixtureKits(next.id)),
        ),
      if (upcoming.comingUp.isNotEmpty) ...[
        const SizedBox(height: 10),
        ComingUpCard(
          fixtures: upcoming.comingUp,
          teamId: team.id,
          onTap: (f) => context.open(Routes.teamMatch(f.id)),
        ),
      ],
      if (!wide) ...calendar,
      DashboardSectionTitle(
        title: 'Needs you',
        trailing: needs.isEmpty ? null : '${needs.length} to do',
      ),
      if (needs.isEmpty)
        const TeamCaughtUpCard()
      else
        TeamNeedsCard(rows: needs),
    ];

    final glance = [
      DashboardSectionTitle(
        title: 'Squad at a glance',
        trailing: 'Squad ›',
        onTap: () => context.open(Routes.team),
        top: wide ? 2 : 20,
      ),
      _tiles(team, groups, fixtures, next?.kickoffAt, wide),
    ];

    final fee = _feeCard(team);
    final side = <Widget>[
      if (wide) ...calendar,
      if (fee != null) ...[
        DashboardSectionTitle(
          title: 'Season fee',
          trailing: 'Season fee ›',
          onTap: () => context.open(Routes.teamFee),
          top: wide ? 26 : 20,
        ),
        fee,
      ],
      if (waiting.isNotEmpty) ...[
        DashboardSectionTitle(
          title: 'Waiting on the FA',
          trailing: '${waiting.length} sent',
        ),
        TeamNeedsCard(rows: waiting),
      ],
      const DashboardSectionTitle(title: 'From GEDFA'),
      _fromGedfa(),
    ];

    final later = [
      const DashboardSectionTitle(
        title: 'Coming later',
        trailing: 'After match reports',
      ),
      ComingLater(wide: wide, items: teamComingLater),
      const _LiveNote(),
    ];

    final List<Widget> content = wide
        ? [
            ...glance,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: matches,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: side,
                  ),
                ),
              ],
            ),
            ...later,
          ]
        : [...matches, ...glance, ...side, ...later];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        header,
        Align(
          alignment: wide ? Alignment.topLeft : Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
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
                  ...content,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Squad at a glance (TDb).
  Widget _tiles(
    Team team,
    List<AgeGroup> groups,
    List<Fixture> fixtures,
    DateTime? nextKickoff,
    bool wide,
  ) {
    final players = ref.watch(teamPlayersProvider).value ?? const [];
    final settings = ref.watch(leagueSettingsProvider).value;
    final ready = matchReadyTile(
      categories: team.categories,
      players: players,
      juvenileGroups: groups,
      matchdaySquad: settings?.matchdaySquad ?? 18,
      minPlayers: settings?.minPlayers ?? 7,
    );
    return TeamGlanceTiles(
      glance: SquadGlance.of(players, fixtures, DateTime.now()),
      ready: ready.readiness,
      readyGroup: ready.group,
      maxSquad: settings?.maxSquadSize ?? 30,
      inDivision: team.categories.contains(Competition.division),
      inJuvenile: team.categories.contains(Competition.juvenile),
      juvenileGroups: groups,
      nextKickoff: nextKickoff,
      wide: wide,
      onSquad: () => context.open(Routes.team),
      onJuvenile: () => context.open(Routes.teamClub),
      onFixtures: () => context.open(Routes.teamFixtures),
    );
  }

  /// Season fee (TDb); none before the fee loads or without a club account.
  Widget? _feeCard(Team team) {
    final uid = team.requestUid;
    if (uid == null) return null;
    final summary = ref.watch(feeSummaryProvider(uid)).value;
    if (summary == null) return null;
    final payments = ref.watch(clubPaymentsProvider(uid)).value ?? const [];
    return TeamFeeCard(
      summary: summary,
      waiting: [
        for (final p in payments)
          if (p.status == PaymentStatus.waiting) p,
      ],
      onAdd: () => context.open(Routes.teamAddPayment),
      onHistory: () => context.open(Routes.teamFee),
    );
  }

  /// From GEDFA (TDb): the pinned announcement and the unread notes.
  Widget _fromGedfa() {
    final pinned = ref.watch(pinnedAnnouncementProvider);
    final mark = ref.watch(readMarkProvider).value;
    final notes = ref.watch(myNotificationsProvider).value ?? const [];
    final latest = mark == null
        ? null
        : notes.where((n) => mark.isUnread(n.id, n.updatedAt)).firstOrNull;
    return FromGedfaCard(
      pinned: pinned,
      unread: ref.watch(unreadCountProvider),
      latestUnread: latest?.title,
      onPinned: () => context.open(Routes.teamAnnouncement(pinned!.id)),
      onBell: () => context.open(Routes.teamNotifications),
    );
  }

  /// Waiting on the FA (TDb): what the team sent that the FA hasn't
  /// answered yet. Grey: nothing to do but wait.
  List<TeamNeedRow> _waitingRows(Team team) {
    final players = ref.watch(teamPlayersProvider).value ?? const [];
    final changes = ref.watch(myTeamChangesProvider).value ?? const [];
    final correction = ref.watch(myCorrectionRequestProvider).value;
    final screeningPlanned =
        ref.watch(upcomingScreeningsProvider).value?.isNotEmpty ?? false;
    final uid = team.requestUid;
    final payments = uid == null
        ? const <Payment>[]
        : ref.watch(clubPaymentsProvider(uid)).value ?? const <Payment>[];

    final divisionWaiting = players
        .where((p) => !p.isJuvenile && p.status == ApprovalStatus.pending)
        .length;
    final children = players.where((p) => p.isWaitingForScreening).length;

    TeamNeedRow row(IconData icon, String label, String detail, String route) =>
        TeamNeedRow(
          icon: icon,
          tone: AccentTone.grey,
          label: label,
          detail: detail,
          onTap: () => context.open(route),
        );

    return [
      if (divisionWaiting > 0)
        row(
          Icons.person_search_rounded,
          divisionWaiting == 1 ? '1 player' : '$divisionWaiting players',
          'The FA checks each one',
          Routes.team,
        ),
      // With a screening day planned, they are in Needs you instead
      if (children > 0 && !screeningPlanned)
        row(
          Icons.child_care_rounded,
          children == 1 ? '1 child' : '$children children',
          'Waiting for the FA to plan a screening day',
          Routes.team,
        ),
      for (final c in changes)
        if (c.isPending)
          row(
            Icons.edit_rounded,
            c.summary,
            c.createdAt == null
                ? 'Asked the FA'
                : 'Asked ${formatDayMonth(c.createdAt!)}',
            Routes.teamClub,
          ),
      for (final p in payments)
        if (p.status == PaymentStatus.waiting)
          row(
            Icons.receipt_long_rounded,
            p.amount == null ? 'Payment' : 'Payment ${cedis(p.amount!)}',
            [
              p.method.label,
              if (p.createdAt case final at?) formatDayMonth(at),
            ].join(' · '),
            Routes.teamFee,
          ),
      if (correction?.status == CorrectionStatus.sentBack)
        row(
          Icons.assignment_return_rounded,
          'Your correction',
          [
            if (correction!.sentBackAt case final at?)
              'Sent back ${formatDayMonth(at)}',
            'the FA checks it',
          ].join(' · '),
          Routes.team,
        ),
    ];
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

/// The line at the bottom: the numbers change by themselves.
class _LiveNote extends StatelessWidget {
  const _LiveNote();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt_rounded, size: 15, color: muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Live · updates by itself',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
