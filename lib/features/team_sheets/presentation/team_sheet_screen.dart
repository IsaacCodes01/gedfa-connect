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
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

/// Team sheet, step 1 Players (3.1a2, mockups MS2 and MS3): the team picks
/// who starts and who sits on the bench for one match, from its approved
/// players, and saves. Saving again replaces the sheet, until it locks
/// 1 hour before kick-off. Roles and numbers (3.1b) and the Check step
/// (3.1c) come next.
class TeamSheetScreen extends ConsumerWidget {
  const TeamSheetScreen({super.key, required this.fixtureId});

  final String fixtureId;

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
      ),
    );
  }
}

class _Builder extends ConsumerStatefulWidget {
  const _Builder({
    required this.fixture,
    required this.team,
    required this.players,
    required this.limits,
  });

  final Fixture fixture;
  final Team team;
  final List<Player> players;
  final SheetLimits limits;

  @override
  ConsumerState<_Builder> createState() => _BuilderState();
}

class _BuilderState extends ConsumerState<_Builder> {
  /// What the team changed; null = the saved sheet as it is.
  SheetPicks? _picks;
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

  Future<void> _save(SheetPicks picks) async {
    final uid = ref.read(appUserProvider).value?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(teamSheetRepositoryProvider)
          .save(fixture: f, teamId: widget.team.id, picks: picks, uid: uid);
      if (!mounted) return;
      final due = f.sheetDueAt;
      AppToast.success(
        context,
        due == null
            ? 'Team sheet saved.'
            : 'Team sheet saved. You can change it until '
                  '${formatShortDate(due)}, ${formatTime(due)}.',
      );
      setState(() => _picks = null);
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

    final mine = [
      for (final p in widget.players)
        if (_canPlay(p)) p,
    ];
    final pickable = [
      for (final p in mine)
        if (p.isApproved) p,
    ]..sort((a, b) => a.jerseyNo.compareTo(b.jerseyNo));
    final waiting = mine.length - pickable.length;
    final pickableIds = {for (final p in pickable) p.id};

    // A player picked on the saved sheet who is no longer approved drops off
    final savedPicks = saved == null
        ? const SheetPicks()
        : SheetPicks(starters: saved.starters, bench: saved.bench);
    final fromSaved = savedPicks.keepOnly(pickableIds);
    final dropped = savedPicks.size - fromSaved.size;
    final picks = _picks ?? fromSaved;
    final dirty = _picks != null || dropped > 0;

    final due = f.sheetDueAt;
    final locked =
        !f.isScheduled || due == null || !DateTime.now().isBefore(due);

    final check = SheetCheck.of(
      picks,
      widget.limits,
      goalkeepers: {
        for (final p in pickable)
          if (p.position == Position.gk) p.id,
      },
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

    final subtitle = '${team.sideName(f.category)} · ${f.competitionLabel}';
    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Team sheet',
        subtitle: subtitle,
        leading: AppBackButton(fallback: Routes.teamMatch(f.id)),
      ),
      body: Column(
        children: [
          _MatchBar(fixture: f, teamId: team.id, locked: locked),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                ResponsiveCenter(
                  maxWidth: 720,
                  child: Column(
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
                        check: check,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Name, number or ID',
                          isDense: true,
                        ),
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
                                  pick: picks.pickOf(p.id),
                                  badge: armbands.badgeFor(p.id),
                                  profile: profiles[p.id],
                                  playingUp:
                                      f.ageGroup != null &&
                                      p.ageGroup != f.ageGroup,
                                  benchOpen:
                                      picks.starters.length >=
                                          SheetLimits.eleven ||
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SaveBar(
        check: check,
        saved: saved,
        dirty: dirty,
        busy: _busy,
        locked: locked,
        onSave: () => _save(picks),
      ),
    );
  }

  static String _plural(PositionGroup g) => switch (g) {
    PositionGroup.gk => 'Goalkeepers',
    PositionGroup.def => 'Defenders',
    PositionGroup.mid => 'Midfielders',
    PositionGroup.fwd => 'Forwards',
  };
}

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

/// Green, red or grey chips: goalkeeper starts, at least 7, bench room.
class _Checks extends StatelessWidget {
  const _Checks({
    required this.picks,
    required this.limits,
    required this.check,
  });

  final SheetPicks picks;
  final SheetLimits limits;
  final SheetCheck check;

  @override
  Widget build(BuildContext context) {
    final noKeeper = check.problems.contains('A goalkeeper must start.');
    final enough = picks.starters.length >= limits.minPlayers;
    final room = limits.maxBench - picks.bench.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Chip(
          ok: !noKeeper && picks.starters.isNotEmpty,
          text: noKeeper ? 'No goalkeeper starts' : 'Goalkeeper starts',
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
    required this.pick,
    required this.badge,
    required this.profile,
    required this.playingUp,
    required this.benchOpen,
    required this.enabled,
    required this.onTap,
  });

  final Player player;
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
              '${p.jerseyNo}',
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

/// The message (first problem, a warning, or ready / saved) and Save.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.check,
    required this.saved,
    required this.dirty,
    required this.busy,
    required this.locked,
    required this.onSave,
  });

  final SheetCheck check;
  final TeamSheet? saved;
  final bool dirty;
  final bool busy;
  final bool locked;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final savedAt = saved?.savedAt;
    final (tone, icon, text) = locked
        ? (AccentTone.grey, Icons.lock_outline, 'Locked: no more changes.')
        : check.problems.isNotEmpty
        ? (AccentTone.red, Icons.error_outline, check.problems.first)
        : check.warnings.isNotEmpty
        ? (AccentTone.gold, Icons.info_outline, check.warnings.first)
        : !dirty && savedAt != null
        ? (
            AccentTone.green,
            Icons.task_alt,
            'Saved ${formatShortDate(savedAt)}, '
                '${formatTime(savedAt)} · '
                '${saved!.playerCount} players',
          )
        : (AccentTone.green, Icons.check_circle_outline, 'Ready to save');
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
                  FilledButton.icon(
                    onPressed:
                        locked ||
                            busy ||
                            !check.canSave ||
                            (!dirty && saved != null)
                        ? null
                        : onSave,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      saved == null ? 'Save team sheet' : 'Save changes',
                    ),
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
