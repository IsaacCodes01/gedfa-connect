import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/players/data/player_profile_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/player_profile.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/team_sheets/data/team_sheet_repository.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_picks.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_roles.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_status.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/widgets/sheet_check_step.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/widgets/sheet_roles_step.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/widgets/shirt_numbers.dart';
import 'package:gedfa_connect/features/teams/data/team_profile_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

/// Team sheet for one match (3.1). Step 1 Players (3.1a2, MS2, MS3): who
/// starts and who sits on the bench, from the approved players. Step 2
/// Roles & numbers (3.1b, MS4): captain, vice-captain, goalkeeper, shirt
/// numbers for this match (MS4b, MS4c) and officials, then Save. Saving
/// again replaces the sheet, until it locks 1 hour before kick-off. Step 3
/// Check (3.1c, MS5): the sheet as it will look and Save. On a laptop
/// (MS7) players sit on the left and the sheet, roles and checks on the
/// right, with no steps.
class TeamSheetScreen extends ConsumerWidget {
  const TeamSheetScreen({
    super.key,
    required this.fixtureId,
    this.startOnCheck = false,
  });

  final String fixtureId;

  /// Open on step 3, Check ("View sheet" on Home and Match details).
  final bool startOnCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixture = ref.watch(fixtureProvider(fixtureId));
    final team = ref.watch(myTeamProvider);
    final players = ref.watch(teamPlayersProvider);
    final settings = ref.watch(leagueSettingsProvider);

    Widget page(Widget body, {String? subtitle}) => Scaffold(
      appBar: GedfaAppBar(
        title: 'Team sheet',
        subtitle: subtitle,
        leading: AppBackButton(fallback: Routes.teamMatch(fixtureId)),
      ),
      body: body,
    );

    final error =
        fixture.error ?? team.error ?? players.error ?? settings.error;
    if (error != null) {
      return page(ErrorView(message: appErrorMessage(error)));
    }
    final f = fixture.value;
    final t = team.value;
    final all = players.value;
    final s = settings.value;
    if (f == null || t == null || all == null || s == null) {
      return page(
        fixture.isLoading ||
                team.isLoading ||
                players.isLoading ||
                settings.isLoading
            ? const LoadingView()
            : const EmptyView(
                icon: Icons.event_busy_outlined,
                title: 'Match not found',
                message: 'It may have been cancelled or removed.',
              ),
      );
    }
    return _Builder(
      fixture: f,
      team: t,
      players: all,
      limits: SheetLimits(
        matchdaySquad: s.matchdaySquad,
        minPlayers: s.minPlayers,
        matchdaySubs: s.matchdaySubs,
      ),
      startOnCheck: startOnCheck,
    );
  }
}

class _Builder extends ConsumerStatefulWidget {
  const _Builder({
    required this.fixture,
    required this.team,
    required this.players,
    required this.limits,
    required this.startOnCheck,
  });

  final Fixture fixture;
  final Team team;
  final List<Player> players;
  final SheetLimits limits;
  final bool startOnCheck;

  @override
  ConsumerState<_Builder> createState() => _BuilderState();
}

class _BuilderState extends ConsumerState<_Builder> {
  /// What the team changed; null = the saved sheet as it is.
  SheetPicks? _picks;

  /// Captain, vice-captain, goalkeeper and changed numbers the team chose;
  /// null = the saved sheet's, or the armbands in Profiles.
  SheetRoles? _roles;

  /// The ticked officials (indexes into Team profile's list); null = the
  /// saved sheet's, or all of them.
  Set<int>? _officialPicks;
  late _View _view = widget.startOnCheck ? _View.check : _View.players;
  String _search = '';
  bool _busy = false;

  Fixture get f => widget.fixture;

  /// The players who may go on this sheet: approved, this competition;
  /// in a juvenile match, its age group and the younger ones (playing up).
  bool _canPlay(Player p) {
    if (p.category != f.category) return false;
    if (f.ageGroup == null) return true;
    final group = p.ageGroup;
    return group != null && group.index <= f.ageGroup!.index;
  }

  /// Team manager first, head coach second, then the other ticked ones in
  /// Team profile's order (the rules check the first two).
  static List<Official> _ordered(List<Official> all, Set<int> ticked) {
    final picked = [
      for (final (i, o) in all.indexed)
        if (ticked.contains(i)) o,
    ];
    Official? first(OfficialRole role) {
      for (final o in picked) {
        if (o.role == role) return o;
      }
      return null;
    }

    final manager = first(OfficialRole.teamManager);
    final coach = first(OfficialRole.headCoach);
    return [
      ?manager,
      ?coach,
      for (final o in picked)
        if (!identical(o, manager) && !identical(o, coach)) o,
    ];
  }

  Future<void> _save({
    required SheetPicks picks,
    required SheetRoles roles,
    required Map<String, int> numbers,
    required List<Official> officials,
  }) async {
    final uid = ref.read(appUserProvider).value?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(teamSheetRepositoryProvider)
          .save(
            fixture: f,
            teamId: widget.team.id,
            picks: picks,
            roles: roles,
            numbers: numbers,
            officials: officials,
            uid: uid,
          );
      if (!mounted) return;
      final due = f.sheetDueAt;
      AppToast.success(
        context,
        due == null
            ? 'Team sheet saved.'
            : 'Team sheet saved. You can change it until '
                  '${formatShortDate(due)}, ${formatTime(due)}.',
      );
      setState(() {
        _picks = null;
        _roles = null;
        _officialPicks = null;
      });
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final saved = ref.watch(teamSheetProvider((f.id, team.id))).value;
    final profiles = ref.watch(teamProfilesProvider).value ?? const {};
    final armbands =
        ref.watch(armbandsProvider(f.category.name)).value ?? const Armbands();
    final teamOfficials =
        ref.watch(myTeamDetailsProvider).value?.officials ?? const <Official>[];

    final mine = [
      for (final p in widget.players)
        if (_canPlay(p)) p,
    ];
    final pickable = [
      for (final p in mine)
        if (p.isApproved) p,
    ]..sort((a, b) => a.jerseyNo.compareTo(b.jerseyNo));
    final waiting = mine.length - pickable.length;
    final byId = {for (final p in pickable) p.id: p};
    final usual = {for (final p in pickable) p.id: p.jerseyNo};
    final keepers = {
      for (final p in pickable)
        if (p.position == Position.gk) p.id,
    };

    // A player picked on the saved sheet who is no longer approved drops off
    final savedPicks = saved == null
        ? const SheetPicks()
        : SheetPicks(starters: saved.starters, bench: saved.bench);
    final fromSaved = savedPicks.keepOnly(byId.keys.toSet());
    final dropped = savedPicks.size - fromSaved.size;
    final picks = _picks ?? fromSaved;

    // Roles: the team's choice, else the saved sheet's, else Profiles
    final savedRoles = saved == null || saved.captainId == null
        ? SheetRoles(
            captainId: armbands.captainId,
            viceCaptainId: armbands.viceCaptainId,
          )
        : SheetRoles(
            captainId: saved.captainId,
            viceCaptainId: saved.viceCaptainId,
            goalkeeperId: saved.goalkeeperId,
            numbers: {
              for (final e in saved.numbers.entries)
                if (usual[e.key] != e.value) e.key: e.value,
            },
          );
    final chosen = _roles ?? savedRoles;
    final roles = chosen.fitTo(picks, keepers: keepers);
    final numbers = roles.numbersFor(picks, usual);

    // Officials: the team's ticks, else the saved sheet's, else everyone.
    // The team manager and head coach are always ticked.
    String key(Official o) => '${o.role.name}|${o.name.trim()}';
    final savedOfficials = {
      for (final o in saved?.officials ?? const <Official>[]) key(o),
    };
    final ticked = {
      for (final (i, o) in teamOfficials.indexed)
        if (o.role.isRequired ||
            (_officialPicks?.contains(i) ??
                (savedOfficials.isEmpty || savedOfficials.contains(key(o)))))
          i,
    };
    final sheetOfficials = _ordered(teamOfficials, ticked);
    final officialsReady =
        sheetOfficials.length >= 2 &&
        sheetOfficials[0].role == OfficialRole.teamManager &&
        sheetOfficials[1].role == OfficialRole.headCoach;

    // A sheet saved before roles existed (3.1a2) needs saving again
    final dirty =
        _picks != null ||
        _roles != null ||
        _officialPicks != null ||
        dropped > 0 ||
        (saved != null && saved.captainId == null);

    final due = f.sheetDueAt;
    final locked =
        !f.isScheduled || due == null || !DateTime.now().isBefore(due);

    final check = SheetCheck.of(
      picks,
      widget.limits,
      roles: roles,
      numbers: numbers,
      officialsReady: officialsReady,
      notAvailable: {
        for (final p in pickable)
          if (!(profiles[p.id]?.isAvailable ?? true)) p.id: p.fullName,
      },
    );

    void tap(Player p, Pick target) {
      final result = target == Pick.start
          ? picks.tapStart(p.id)
          : picks.tapBench(p.id, widget.limits);
      if (result.refused case final why?) {
        AppToast.warning(context, why);
        return;
      }
      setState(() => _picks = result.picks);
    }

    void setRoles(SheetRoles next) => setState(() => _roles = next);

    void back() => setState(
      () => _view = switch (_view) {
        _View.numbers || _View.check => _View.roles,
        _ => _View.players,
      },
    );

    // "Use last sheet" (3.1c): the latest sheet of another match in this
    // competition; only players still approved, and changed numbers only
    // for players still here.
    final last = lastSheetFor(
      f,
      (ref.watch(myTeamSheetsProvider).value ?? const {}).values,
    );
    void useLast() {
      final l = last!;
      final copied = {for (final o in l.officials) key(o)};
      setState(() {
        _picks = SheetPicks(
          starters: l.starters,
          bench: l.bench,
        ).keepOnly(byId.keys.toSet());
        _roles = SheetRoles(
          captainId: l.captainId ?? armbands.captainId,
          viceCaptainId: l.captainId == null
              ? armbands.viceCaptainId
              : l.viceCaptainId,
          goalkeeperId: l.goalkeeperId,
          numbers: {
            for (final e in l.numbers.entries)
              if (usual[e.key] != null && usual[e.key] != e.value)
                e.key: e.value,
          },
        );
        if (copied.isNotEmpty) {
          _officialPicks = {
            for (final (i, o) in teamOfficials.indexed)
              if (copied.contains(key(o))) i,
          };
        }
      });
      AppToast.info(
        context,
        'Copied your sheet saved ${formatShortDate(l.savedAt!)}. '
        'Check it, then save.',
      );
    }

    final opponent = f.opponentOf(team.id).name;
    final kickoff = f.kickoffAt;
    final starters = [for (final id in picks.starters) ?byId[id]];
    final bench = [for (final id in picks.bench) ?byId[id]];

    Widget paper({bool live = false}) => SheetPaper(
      title: live ? 'The sheet' : team.sideName(f.category),
      subtitle: live
          ? 'Fills in as you pick'
          : [
              'v $opponent',
              f.competitionLabel,
              if (kickoff != null)
                '${formatShortDate(kickoff)}, ${formatTime(kickoff)}',
              f.venue,
            ].join(' · '),
      kit: f.kitOf(team.id).kit,
      starters: starters,
      bench: bench,
      maxBench: widget.limits.maxBench,
      numbers: numbers,
      roles: roles,
      officials: sheetOfficials,
    );

    // The checks in words (MS5): what is wrong in red, what is right in
    // green, warnings in gold, then the substitutes rule
    final changed = [
      for (final p in [...starters, ...bench])
        if (numbers[p.id] != p.jerseyNo) '${p.fullName} wears ${numbers[p.id]}',
    ];
    final checkLines = <CheckLine>[
      for (final p in [...check.problems, ...check.roleProblems])
        (AccentTone.red, p),
      if (check.canSave) ...[
        (AccentTone.green, '${picks.size} players, all approved by GEDFA'),
        (
          AccentTone.green,
          '${picks.starters.length} starting with a goalkeeper · '
              '${picks.bench.isEmpty ? 'no bench' : '${picks.bench.length} on the bench (${widget.limits.maxBench} at most)'}',
        ),
        (
          AccentTone.green,
          'Captain starts · ${roles.viceCaptainId == null ? 'no vice-captain' : 'vice-captain on the sheet'}',
        ),
        (AccentTone.green, 'Team manager and head coach on the sheet'),
        (
          AccentTone.green,
          '${picks.size} different shirt numbers · '
              '${changed.isEmpty ? 'everyone in their usual number' : '${changed.length} changed for this match (${changed.take(2).join(', ')}${changed.length > 2 ? '…' : ''})'}',
        ),
      ],
      for (final w in check.warnings) (AccentTone.gold, w),
      (
        AccentTone.grey,
        '${widget.limits.matchdaySubs} substitutes may come on in the match '
            '(League settings)',
      ),
    ];
    final dueText = due == null
        ? ''
        : '${formatShortDate(due)}, ${formatTime(due)}';
    final checkHint = locked
        ? 'Locked: this is the sheet as it was saved.'
        : 'After saving you can change the sheet until $dueText. Then it '
              'locks, and $opponent and the referee can see it too.';

    Widget rolesStep() => RolesStep(
      players: byId,
      picks: picks,
      roles: roles,
      keeperPickedForYou: roles.keeperPickedFor(chosen),
      armbands: armbands,
      numbers: numbers,
      usual: usual,
      officials: teamOfficials,
      officialPicks: ticked,
      enabled: !locked && !_busy,
      onCaptain: (id) => setRoles(chosen.withCaptain(id)),
      onVice: (id) => setRoles(chosen.withVice(id)),
      onGoalkeeper: (id) => setRoles(chosen.withGoalkeeper(id)),
      onNumbers: () => setState(() => _view = _View.numbers),
      onOfficial: (i) => setState(
        () => _officialPicks = ticked.contains(i)
            ? ({...ticked}..remove(i))
            : {...ticked, i},
      ),
    );

    Widget playersList() => _playersList(
      picks: picks,
      pickable: pickable,
      waiting: waiting,
      dropped: dropped,
      locked: locked,
      roles: roles,
      numbers: numbers,
      armbands: armbands,
      profiles: profiles,
      tap: tap,
      onUseLast: last == null || locked || _busy ? null : useLast,
    );

    final saveButton = FilledButton.icon(
      onPressed: locked || _busy || !check.canSave || (!dirty && saved != null)
          ? null
          : () => _save(
              picks: picks,
              roles: roles,
              numbers: numbers,
              officials: sheetOfficials,
            ),
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(saved == null ? 'Save team sheet' : 'Save changes'),
    );

    // Laptop and tablet (MS7): players on the left, the sheet on the right
    // filling in as players are picked, roles and checks under it; no steps
    final wide =
        MediaQuery.sizeOf(context).width >= 840 && _view != _View.numbers;

    final Widget body;
    final Widget foot;
    if (wide) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: playersList()),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                paper(live: true),
                rolesStep(),
                const _SectionHead(title: 'Checks', note: ''),
                SheetCheckList(lines: checkLines),
                _Hint(checkHint),
              ],
            ),
          ),
        ],
      );
      foot = _Foot(
        message: _message(
          locked: locked,
          problems: [...check.problems, ...check.roleProblems],
          warnings: check.warnings,
          saved: saved,
          dirty: dirty,
          ready: 'Ready to save',
        ),
        children: [saveButton],
      );
    } else {
      switch (_view) {
        case _View.players:
          body = playersList();
          foot = _Foot(
            message: _message(
              locked: locked,
              problems: check.problems,
              warnings: check.warnings,
              saved: saved,
              dirty: dirty,
              ready: 'Players ready: next, roles and numbers',
            ),
            children: [
              FilledButton.icon(
                onPressed: check.canGoOn
                    ? () => setState(() => _view = _View.roles)
                    : null,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next: Roles & numbers'),
              ),
            ],
          );
        case _View.roles:
          body = rolesStep();
          foot = _Foot(
            message: _message(
              locked: locked,
              problems: [...check.problems, ...check.roleProblems],
              warnings: check.warnings,
              saved: saved,
              dirty: dirty,
              ready: 'Roles ready: next, check the sheet',
            ),
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Players'),
              ),
              FilledButton.icon(
                onPressed: check.canSave
                    ? () => setState(() => _view = _View.check)
                    : null,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next: Check'),
              ),
            ],
          );
        case _View.check:
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              paper(),
              const _SectionHead(title: 'Checks', note: ''),
              SheetCheckList(lines: checkLines),
              _Hint(checkHint),
            ],
          );
          foot = _Foot(
            message: _message(
              locked: locked,
              problems: [...check.problems, ...check.roleProblems],
              warnings: check.warnings,
              saved: saved,
              dirty: dirty,
              ready: 'Ready to save',
            ),
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Roles'),
              ),
              saveButton,
            ],
          );
        case _View.numbers:
          final clash = SheetRoles.clashesIn(numbers).isNotEmpty;
          body = ShirtNumbersView(
            starters: starters,
            bench: bench,
            numbers: numbers,
            enabled: !locked && !_busy,
            onNumber: (p, n) =>
                setRoles(chosen.withNumber(p.id, n, usual: p.jerseyNo)),
          );
          foot = _Foot(
            message: clash
                ? (
                    AccentTone.red,
                    Icons.error_outline,
                    'Fix the clash to go on',
                  )
                : (
                    AccentTone.grey,
                    Icons.info_outline,
                    'Tap a player to give another number for this match.',
                  ),
            children: [
              FilledButton(
                onPressed: clash ? null : back,
                child: const Text('Done'),
              ),
            ],
          );
      }
    }

    final atStart = wide || _view == _View.players;
    return PopScope(
      canPop: atStart,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: GedfaAppBar(
          title: _view == _View.numbers ? 'Shirt numbers' : 'Team sheet',
          subtitle: _view == _View.numbers
              ? 'v $opponent · this match only'
              : '${team.sideName(f.category)} · ${f.competitionLabel}',
          leading: atStart
              ? AppBackButton(fallback: Routes.teamMatch(f.id))
              : IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: back,
                ),
        ),
        body: Column(
          children: [
            if (_view != _View.numbers) ...[
              _MatchBar(fixture: f, teamId: team.id, locked: locked),
              if (!wide)
                _Steps(
                  on: switch (_view) {
                    _View.players => 1,
                    _View.check => 3,
                    _ => 2,
                  },
                  canGoOn: check.canGoOn,
                  canCheck: check.canSave,
                  onTap: (step) => setState(
                    () => _view = switch (step) {
                      1 => _View.players,
                      3 => _View.check,
                      _ => _View.roles,
                    },
                  ),
                ),
            ],
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  ResponsiveCenter(maxWidth: wide ? 1200 : 720, child: body),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: foot,
      ),
    );
  }

  /// The first problem (red), a warning (gold), saved (green) or [ready].
  (AccentTone, IconData, String) _message({
    required bool locked,
    required List<String> problems,
    required List<String> warnings,
    required TeamSheet? saved,
    required bool dirty,
    required String ready,
  }) {
    final savedAt = saved?.savedAt;
    return locked
        ? (AccentTone.grey, Icons.lock_outline, 'Locked: no more changes.')
        : problems.isNotEmpty
        ? (AccentTone.red, Icons.error_outline, problems.first)
        : warnings.isNotEmpty
        ? (AccentTone.gold, Icons.info_outline, warnings.first)
        : !dirty && savedAt != null
        ? (
            AccentTone.green,
            Icons.task_alt,
            'Saved ${formatShortDate(savedAt)}, '
                '${formatTime(savedAt)} · '
                '${saved!.playerCount} players',
          )
        : (AccentTone.green, Icons.check_circle_outline, ready);
  }

  /// Step 1: counters, checks, search and the players (MS2, MS3).
  Widget _playersList({
    required SheetPicks picks,
    required List<Player> pickable,
    required int waiting,
    required int dropped,
    required bool locked,
    required SheetRoles roles,
    required Map<String, int> numbers,
    required Armbands armbands,
    required Map<String, PlayerProfile> profiles,
    required void Function(Player p, Pick target) tap,
    required VoidCallback? onUseLast,
  }) {
    final query = _search.trim().toLowerCase();
    bool matches(Player p) =>
        query.isEmpty ||
        p.fullName.toLowerCase().contains(query) ||
        '${p.jerseyNo}' == query ||
        (p.playerCode?.toLowerCase().contains(query) ?? false);
    final shown = [
      for (final p in pickable)
        if (matches(p)) p,
    ];

    // Division: by position. Juvenile: the match's age group first, then
    // the younger groups playing up (mockup MS6).
    final sections = <(String, List<Player>)>[];
    if (f.ageGroup case final group?) {
      final younger = [
        for (final a in AgeGroup.values.reversed)
          if (a.index < group.index) a,
      ];
      for (final g in [group, ...younger]) {
        final list = [
          for (final p in shown)
            if (p.ageGroup == g) p,
        ];
        if (list.isEmpty) continue;
        sections.add((
          g == group ? '${g.label} squad' : 'Playing up from ${g.label}',
          list,
        ));
      }
    } else {
      for (final g in PositionGroup.values) {
        final list = [
          for (final p in shown)
            if (p.positionGroup == g) p,
        ];
        if (list.isNotEmpty) sections.add((_plural(g), list));
      }
    }

    // On the sheet: this match's armbands; off it: the season's (Profiles)
    String? badge(String id) => picks.pickOf(id) == Pick.out
        ? armbands.badgeFor(id)
        : id == roles.captainId
        ? 'C'
        : id == roles.viceCaptainId
        ? 'VC'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (locked)
          const _Banner(
            tone: AccentTone.grey,
            icon: Icons.lock_outline,
            text:
                'This sheet is locked: it closed 1 hour before '
                'kick-off, or the match is no longer scheduled.',
          ),
        if (dropped > 0)
          _Banner(
            tone: AccentTone.gold,
            icon: Icons.info_outline,
            text: dropped == 1
                ? '1 player on your saved sheet is no longer '
                      'approved and was taken off. Save again.'
                : '$dropped players on your saved sheet are no '
                      'longer approved and were taken off. Save '
                      'again.',
          ),
        _Counters(picks: picks, limits: widget.limits),
        const SizedBox(height: 8),
        _Checks(
          picks: picks,
          limits: widget.limits,
          hasKeeper: roles.goalkeeperId != null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Name, number or ID',
                  isDense: true,
                ),
              ),
            ),
            if (onUseLast != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onUseLast,
                icon: const Icon(Icons.content_copy, size: 17),
                label: const Text('Use last sheet'),
              ),
            ],
          ],
        ),
        if (pickable.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyView(
              icon: Icons.group_off_outlined,
              title: 'No approved players yet',
              message:
                  'Only players approved by GEDFA can go on '
                  'a team sheet.',
            ),
          ),
        for (final (title, list) in sections) ...[
          _SectionHead(
            title: title,
            note:
                '${list.where((p) => picks.pickOf(p.id) == Pick.start).length} starting',
          ),
          DashboardCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final p in list)
                  _PlayerRow(
                    player: p,
                    number: numbers[p.id] ?? p.jerseyNo,
                    pick: picks.pickOf(p.id),
                    badge: badge(p.id),
                    profile: profiles[p.id],
                    playingUp: f.ageGroup != null && p.ageGroup != f.ageGroup,
                    benchOpen:
                        picks.starters.length >= SheetLimits.eleven ||
                        picks.pickOf(p.id) == Pick.start,
                    enabled: !locked && !_busy,
                    onTap: (target) => tap(p, target),
                  ),
              ],
            ),
          ),
        ],
        if (waiting > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DashboardCard(
              onTap: () => context.open(Routes.team),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      waiting == 1
                          ? "1 player not approved yet can't be picked"
                          : "$waiting players not approved yet "
                                "can't be picked",
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Text(
                    'Squad ›',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _plural(PositionGroup g) => switch (g) {
    PositionGroup.gk => 'Goalkeepers',
    PositionGroup.def => 'Defenders',
    PositionGroup.mid => 'Midfielders',
    PositionGroup.fwd => 'Forwards',
  };
}

/// Which part of the sheet is on screen: step 1, 2 or 3, or the shirt
/// numbers page opened from step 2.
enum _View { players, roles, check, numbers }

// ---------- Pieces ----------

/// "v Asebu Stars (A) · Sat 14 Nov, 3:00 pm" and when the sheet is due.
class _MatchBar extends StatelessWidget {
  const _MatchBar({
    required this.fixture,
    required this.teamId,
    required this.locked,
  });

  final Fixture fixture;
  final String teamId;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final other = fixture.opponentOf(teamId);
    final kickoff = fixture.kickoffAt;
    final due = fixture.sheetDueAt;
    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            FixtureCrest(side: other, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'v ${other.name} (${fixture.isHome(teamId) ? 'H' : 'A'})'
                '${kickoff == null ? '' : ' · ${formatShortDate(kickoff)}, ${formatTime(kickoff)}'}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (due != null)
              FixtureTag(
                locked
                    ? 'Locked'
                    : 'Due ${formatShortDate(due)} ${formatTime(due)}',
                tone: locked ? AccentTone.grey : AccentTone.gold,
              ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.tone, required this.icon, required this.text});

  final AccentTone tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.background(isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone.foreground(isDark)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}

/// Starting 11 / 11 · Bench 5 / 7 · Squad 16 / 18.
class _Counters extends StatelessWidget {
  const _Counters({required this.picks, required this.limits});

  final SheetPicks picks;
  final SheetLimits limits;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget counter(int value, int max, String label, Color colour) => Expanded(
      child: DashboardCard(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: '$value',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: ' / $max',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : (value / max).clamp(0, 1),
                minHeight: 5,
                color: colour,
                backgroundColor: AccentTone.grey.background(isDark),
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        counter(
          picks.starters.length,
          SheetLimits.eleven,
          'Starting',
          AccentTone.green.foreground(isDark),
        ),
        const SizedBox(width: 8),
        counter(
          picks.bench.length,
          limits.maxBench,
          'Bench',
          AccentTone.blue.foreground(isDark),
        ),
        const SizedBox(width: 8),
        counter(
          picks.size,
          limits.matchdaySquad,
          'Squad',
          Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

/// Green or gold chips: goalkeeper, at least 7, bench room.
class _Checks extends StatelessWidget {
  const _Checks({
    required this.picks,
    required this.limits,
    required this.hasKeeper,
  });

  final SheetPicks picks;
  final SheetLimits limits;

  /// A goalkeeper starts: picked in step 2, or the only registered
  /// goalkeeper in the 11.
  final bool hasKeeper;

  @override
  Widget build(BuildContext context) {
    final enough = picks.starters.length >= limits.minPlayers;
    final room = limits.maxBench - picks.bench.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (hasKeeper)
          const _Chip(ok: true, text: 'Goalkeeper starts')
        else
          FixtureTag(
            picks.starters.isEmpty
                ? 'No goalkeeper yet'
                : 'Goalkeeper: pick one in step 2',
            tone: AccentTone.gold,
          ),
        _Chip(ok: enough, text: 'At least ${limits.minPlayers} starting'),
        if (picks.starters.length >= SheetLimits.eleven)
          FixtureTag(
            room <= 0 ? 'Bench full' : '$room more fit on the bench',
            tone: room <= 0 ? AccentTone.gold : AccentTone.grey,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) => FixtureTag(
    '${ok ? '✓' : '✕'} $text',
    tone: ok ? AccentTone.green : AccentTone.red,
  );
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: .4,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: style)),
          Text(note, style: style),
        ],
      ),
    );
  }
}

/// One player: photo, number, name (C / VC), position · ID, warnings, and
/// the 11 | Bench switch.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.number,
    required this.pick,
    required this.badge,
    required this.profile,
    required this.playingUp,
    required this.benchOpen,
    required this.enabled,
    required this.onTap,
  });

  final Player player;

  /// The shirt number for this match (the usual one unless changed).
  final int number;
  final Pick pick;
  final String? badge;
  final PlayerProfile? profile;
  final bool playingUp;
  final bool benchOpen;
  final bool enabled;
  final void Function(Pick target) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = player;
    final away = profile != null && !profile!.isAvailable;
    final back = profile?.expectedBack;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          PlayerAvatar(name: p.fullName, url: p.thumbUrl, size: 36),
          SizedBox(
            width: 32,
            child: Text(
              '$number',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (badge case final b?) ...[
                      const SizedBox(width: 4),
                      _Armband(b),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 5,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${p.position.code} · ${p.playerCode ?? ''}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (playingUp && p.ageGroup != null)
                      FixtureTag(
                        '${p.ageGroup!.label} ↑',
                        tone: AccentTone.violet,
                      ),
                    if (away)
                      FixtureTag(
                        back == null
                            ? profile!.availability.label
                            : '${profile!.availability.label} · back '
                                  '${formatDayMonth(back)}',
                        tone: AccentTone.gold,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _PickSwitch(
            pick: pick,
            benchOpen: benchOpen,
            enabled: enabled,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _Armband extends StatelessWidget {
  const _Armband(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final captain = label == 'C';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: captain
            ? const Color(0xFFFCD116)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: captain ? const Color(0xFF3A2C00) : null,
        ),
      ),
    );
  }
}

/// [ 11 | Bench ]: tap one to pick, tap it again to take the player off.
class _PickSwitch extends StatelessWidget {
  const _PickSwitch({
    required this.pick,
    required this.benchOpen,
    required this.enabled,
    required this.onTap,
  });

  final Pick pick;
  final bool benchOpen;
  final bool enabled;
  final void Function(Pick target) onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    Widget part(String label, Pick target, AccentTone tone, bool dim) {
      final on = pick == target;
      return Semantics(
        button: true,
        selected: on,
        label: target == Pick.start ? 'Starting 11' : 'Bench',
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: enabled ? () => onTap(target) : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: on ? tone.foreground(isDark) : null,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Opacity(
              opacity: dim && !on ? .4 : 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: on
                      ? (isDark ? const Color(0xFF0B1626) : Colors.white)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AccentTone.grey.background(isDark),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          part('11', Pick.start, AccentTone.green, false),
          part('Bench', Pick.bench, AccentTone.blue, !benchOpen),
        ],
      ),
    );
  }
}

/// "1 · Players   2 · Roles & numbers   3 · Check".
class _Steps extends StatelessWidget {
  const _Steps({
    required this.on,
    required this.canGoOn,
    required this.canCheck,
    required this.onTap,
  });

  final int on;

  /// Step 1 is done (step 2 may open); the roles too (step 3 may open).
  final bool canGoOn;
  final bool canCheck;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget step(int n, String label) {
      final current = n == on;
      final done = n < on;
      final colour = current
          ? scheme.primary
          : done
          ? scheme.onSurface
          : scheme.onSurfaceVariant;
      return Expanded(
        child: InkWell(
          onTap: current || (n == 2 && !canGoOn) || (n == 3 && !canCheck)
              ? null
              : () => onTap(n),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: current ? scheme.primary : scheme.outlineVariant,
                  width: current ? 2.5 : 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (done)
                  Icon(Icons.check_circle, size: 16, color: colour)
                else
                  Text(
                    '$n ·',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colour,
                    ),
                  ),
                const SizedBox(width: 5),
                // A large text size on a small phone ends in "…"
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colour,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: scheme.surface,
      child: Row(
        children: [
          step(1, 'Players'),
          step(2, 'Roles & numbers'),
          step(3, 'Check'),
        ],
      ),
    );
  }
}

/// The bottom bar: a message (red, gold, green or grey) and the buttons.
class _Foot extends StatelessWidget {
  const _Foot({required this.message, required this.children});

  final (AccentTone, IconData, String) message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (tone, icon, text) = message;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: tone.foreground(isDark)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 12,
                            color: tone.foreground(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (i, child) in children.indexed) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: i == 0 && children.length > 1 ? 2 : 3,
                          child: child,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A grey line of help under a card.
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
