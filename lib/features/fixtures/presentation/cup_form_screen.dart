import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:gedfa_connect/features/fixtures/data/season_maker.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup_format.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:go_router/go_router.dart';

/// A side the FA can put in a cup: a club's Division or juvenile side.
typedef _Side = ({CupEntry entry, String name});

/// FA: a new cup or gala (3.0c1, mockups C2 and C2b). Every approved team
/// plays unless the FA leaves it out. The app suggests the format for the
/// number of teams; the FA sets one match or home and away, what happens
/// when a tie is level, and the round the bracket is fixed from. A gala
/// also has a ground, days and a timetable. Saved as "not drawn yet".
class CupFormScreen extends ConsumerStatefulWidget {
  const CupFormScreen({super.key});

  @override
  ConsumerState<CupFormScreen> createState() => _CupFormScreenState();
}

class _CupFormScreenState extends ConsumerState<CupFormScreen> {
  CupKind _kind = CupKind.cup;
  final _name = TextEditingController(text: _defaultName(CupKind.cup));

  /// The FA typed a name: switching Cup | Gala keeps it.
  bool _nameTyped = false;
  CupWho _who = CupWho.division;

  /// Juvenile: the age group. Open: the age group of the juvenile sides.
  AgeGroup _group = AgeGroup.u17;

  /// Sides left out (CupEntry.key); everyone is in by default.
  final _left = <String>{};
  CupFormat _format = CupFormat.knockout;
  int _legs = 2;
  bool _finalOneMatch = true;
  LevelRule _level = LevelRule.penalties;

  /// Null = the plan's default (quarter-finals, or the start for a gala).
  int? _bracketFrom;
  bool _seeded = false;

  // Gala only
  final _ground = TextEditingController();
  late DateTime _firstDay = _nextSaturday();
  late DateTime _lastDay = _firstDay.add(const Duration(days: 1));
  TimeOfDay _kickoff = const TimeOfDay(hour: 9, minute: 0);
  int _gap = 90;
  bool _busy = false;

  static const _gaps = [60, 75, 90, 105, 120];

  static String _defaultName(CupKind kind) => kind == CupKind.cup
      ? 'GEDFA Cup ${Season.label(Season.current)}'
      : 'GEDFA Gala ${DateTime.now().year}';

  static DateTime _nextSaturday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = (DateTime.saturday - today.weekday) % 7;
    return today.add(Duration(days: days == 0 ? 7 : days));
  }

  /// "1 h 30 min"
  static String _gapText(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return [if (h > 0) '$h h', if (m > 0) '$m min'].join(' ');
  }

  @override
  void dispose() {
    _name.dispose();
    _ground.dispose();
    super.dispose();
  }

  void _setKind(CupKind kind) => setState(() {
        _kind = kind;
        if (!_nameTyped) _name.text = _defaultName(kind);
        _bracketFrom = null;
        if (kind == CupKind.gala) {
          // A gala: straight knockout, one match per tie, no seeding
          _format = CupFormat.knockout;
          _legs = 1;
          _seeded = false;
          if (_level == LevelRule.replay) _level = LevelRule.penalties;
        }
      });

  void _setWho(CupWho who, [AgeGroup? group]) => setState(() {
        _who = who;
        if (group != null) _group = group;
        _left.clear();
        _bracketFrom = null;
      });

  /// The sides of the chosen competition, A to Z (Division first in an
  /// open cup).
  List<_Side> _sides(List<_Side> division, List<_Side> juvenile) =>
      switch (_who) {
        CupWho.division => division,
        CupWho.juvenile => juvenile,
        CupWho.open => [...division, ...juvenile],
      };

  Future<void> _pickDay({required bool first}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: first ? _firstDay : _lastDay,
      firstDate: first ? DateTime(now.year, now.month, now.day) : _firstDay,
      lastDate: now.add(const Duration(days: 400)),
      helpText: first ? 'First day' : 'Last day',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (first) {
        _firstDay = picked;
        if (_lastDay.isBefore(picked)) _lastDay = picked;
      } else {
        _lastDay = picked;
      }
    });
  }

  Future<void> _pickKickoff() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _kickoff,
      helpText: 'First kick-off',
    );
    if (picked != null && mounted) setState(() => _kickoff = picked);
  }

  Future<void> _save(List<_Side> chosen, int bracketFrom) async {
    final name = _name.text.trim();
    if (name.length < 3 || name.length > 60) {
      AppToast.warning(context, 'Give it a name (3 to 60 letters).');
      return;
    }
    if (chosen.length < 2) {
      AppToast.warning(context, 'Choose at least 2 teams.');
      return;
    }
    final gala = _kind == CupKind.gala;
    if (gala && _ground.text.trim().length < 2) {
      AppToast.warning(context, 'Type the ground where the gala is played.');
      return;
    }
    final me = ref.read(authRepositoryProvider).currentUser;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(cupRepositoryProvider).create(
            Cup(
              id: '',
              season: Season.current,
              kind: _kind,
              name: name,
              who: _who,
              ageGroup: _who == CupWho.division ? null : _group,
              entries: [for (final s in chosen) s.entry],
              format: _format,
              legs: _legs,
              finalOneMatch: _legs == 1 || _finalOneMatch,
              level: _level,
              bracketFrom: _format == CupFormat.groups ? 0 : bracketFrom,
              seeded: _seeded,
              stage: CupStage.notDrawn,
              gala: gala
                  ? GalaSettings(
                      ground: _ground.text,
                      firstDay: _firstDay,
                      lastDay: _lastDay,
                      kickoffHour: _kickoff.hour,
                      kickoffMinute: _kickoff.minute,
                      gapMinutes: _gap,
                    )
                  : null,
            ),
            by: me,
          );
      if (!mounted) return;
      AppToast.success(context, '$name saved. The live draw comes next.');
      context.pop();
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final divisionAsync = ref.watch(seasonTeamsProvider(Competition.division));
    final juvenileAsync = ref.watch(seasonTeamsProvider(Competition.juvenile));
    final suspended = <String>{
      for (final t in ref.watch(allTeamsProvider).value ?? const [])
        if (t.isSuspended) t.id,
    };
    final gala = _kind == CupKind.gala;

    Widget body;
    final error = divisionAsync.error ?? juvenileAsync.error;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!divisionAsync.hasValue || !juvenileAsync.hasValue) {
      body = const LoadingView();
    } else {
      final division = [
        for (final t in divisionAsync.requireValue)
          (
            entry: CupEntry(teamId: t.side.id, category: Competition.division),
            name: t.side.name,
          ),
      ];
      final juvenile = [
        for (final t in juvenileAsync.requireValue)
          (
            entry: CupEntry(teamId: t.side.id, category: Competition.juvenile),
            name: t.side.name,
          ),
      ];
      final sides = _sides(division, juvenile);
      final chosen = [
        for (final s in sides)
          if (!_left.contains(s.entry.key)) s,
      ];
      final n = chosen.length;
      final knockout = n >= 2 ? KnockoutPlan(n) : null;
      final groups = gala ? null : GroupPlan.forTeams(n);
      if (groups == null && _format == CupFormat.groups) {
        _format = CupFormat.knockout;
      }
      final choices = knockout?.bracketChoices ?? const [];
      final bracketFrom = choices.any((c) => c.teamsLeft == _bracketFrom)
          ? _bracketFrom!
          : (gala ? 0 : knockout?.defaultBracketFrom ?? 0);

      body = ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SegmentedButton<CupKind>(
              segments: const [
                ButtonSegment(value: CupKind.cup, label: Text('Cup')),
                ButtonSegment(value: CupKind.gala, label: Text('Gala')),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => _setKind(v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Name',
                counterText: '',
              ),
              onChanged: (_) => _nameTyped = true,
            ),
            if (!gala) const DashboardSectionTitle(title: 'Who plays'),
            if (gala) const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Division'),
                  selected: _who == CupWho.division,
                  onSelected: (_) => _setWho(CupWho.division),
                ),
                for (final g in AgeGroup.values)
                  ChoiceChip(
                    label: Text(g == AgeGroup.u13 ? 'Juvenile U13' : g.label),
                    selected: _who == CupWho.juvenile && _group == g,
                    onSelected: (_) => _setWho(CupWho.juvenile, g),
                  ),
                ChoiceChip(
                  label: const Text('Open'),
                  selected: _who == CupWho.open,
                  onSelected: (_) => _setWho(CupWho.open),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _TeamsCard(
              sides: sides,
              left: _left,
              suspended: suspended,
              who: _who,
              group: _group,
              onChanged: (key, isIn) => setState(() {
                isIn ? _left.remove(key) : _left.add(key);
                _bracketFrom = null;
              }),
            ),
            if (_who == CupWho.open)
              _Hint(
                'Open: Division and ${_group.label} sides in one draw, like '
                'the Ghana FA Cup.',
              ),
            if (gala) ...[
              const DashboardSectionTitle(title: 'Where and when'),
              TextField(
                controller: _ground,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Ground',
                  counterText: '',
                  suffixIcon: Icon(Icons.edit_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PickField(
                      label: 'First day',
                      value: formatShortDate(_firstDay),
                      icon: Icons.calendar_today_outlined,
                      onTap: () => _pickDay(first: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickField(
                      label: 'Last day',
                      value: formatShortDate(_lastDay),
                      icon: Icons.calendar_today_outlined,
                      onTap: () => _pickDay(first: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PickField(
                      label: 'First kick-off',
                      value: _kickoff.format(context),
                      icon: Icons.schedule_outlined,
                      onTap: _pickKickoff,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _gap,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Between kick-offs',
                      ),
                      items: [
                        for (final g in _gaps)
                          DropdownMenuItem(value: g, child: Text(_gapText(g))),
                      ],
                      onChanged: (v) => setState(() => _gap = v ?? _gap),
                    ),
                  ),
                ],
              ),
              if (n >= 2)
                _GalaPlanCard(
                  plan: GalaPlan(
                    teams: n,
                    firstDay: _firstDay,
                    lastDay: _lastDay,
                    kickoffHour: _kickoff.hour,
                    kickoffMinute: _kickoff.minute,
                    gapMinutes: _gap,
                  ),
                  rest: _gapText(_gap),
                ),
            ],
            if (!gala && knockout != null) ...[
              DashboardSectionTitle(
                title: 'Format',
                trailing: 'Suggested for $n teams',
              ),
              _FormatOption(
                title: knockout.firstRoundTies == 0
                    ? 'Straight knockout'
                    : 'Knockout with a first round',
                text: knockout.description,
                suggested: true,
                selected: _format == CupFormat.knockout,
                onTap: () => setState(() => _format = CupFormat.knockout),
              ),
              if (groups != null)
                _FormatOption(
                  title: 'Groups, then knockout',
                  text: groups.description,
                  selected: _format == CupFormat.groups,
                  onTap: () => setState(() => _format = CupFormat.groups),
                ),
              const DashboardSectionTitle(title: 'Each round'),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('One match')),
                  ButtonSegment(value: 2, label: Text('Home and away')),
                ],
                selected: {_legs},
                onSelectionChanged: (v) => setState(() {
                  _legs = v.first;
                  if (_legs == 2 && _level == LevelRule.replay) {
                    _level = LevelRule.penalties;
                  }
                }),
              ),
              if (_legs == 2) ...[
                const SizedBox(height: 8),
                const _Hint('Two legs: the aggregate score counts; no away goals.'),
                DashboardCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.emoji_events_outlined),
                    title: const Text(
                      'The final is one match',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('At a ground the FA picks'),
                    value: _finalOneMatch,
                    onChanged: (v) => setState(() => _finalOneMatch = v),
                  ),
                ),
              ],
            ],
            DashboardSectionTitle(
              title: gala ? 'Level at full time' : 'Level at the end',
              trailing: gala ? null : 'After 90 min or both legs',
            ),
            SegmentedButton<LevelRule>(
              showSelectedIcon: false,
              segments: [
                for (final r in LevelRule.values)
                  if (r != LevelRule.replay || !gala)
                    ButtonSegment(
                      value: r,
                      label: Text(r.label, textAlign: TextAlign.center),
                      enabled: r != LevelRule.replay || _legs == 1,
                    ),
              ],
              selected: {_level},
              onSelectionChanged: (v) => setState(() => _level = v.first),
            ),
            if (!gala) ...[
              const SizedBox(height: 8),
              const _Hint('A replay only with one-match rounds.'),
            ],
            if (_format == CupFormat.knockout && choices.isNotEmpty) ...[
              const DashboardSectionTitle(title: 'The draw'),
              DropdownButtonFormField<int>(
                key: ValueKey('from-$n-$_kind'),
                initialValue: bracketFrom,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'The bracket is fixed from',
                ),
                items: [
                  for (final c in choices)
                    DropdownMenuItem(value: c.teamsLeft, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => _bracketFrom = v),
              ),
              if (!gala) ...[
                const SizedBox(height: 8),
                _Hint(
                  bracketFrom == 0
                      ? 'The whole draw is made at once: every club knows '
                          'who it meets if it wins.'
                      : 'Until then each round is drawn after the one '
                          'before it is played. From the '
                          '${roundName(bracketFrom).toLowerCase()} draw, '
                          'every club knows who it meets if it wins.',
                ),
              ],
            ],
            if (!gala) ...[
              if (_format == CupFormat.groups) const SizedBox(height: 12),
              DashboardCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  secondary: const Icon(Icons.workspaces_outline),
                  title: const Text(
                    'Seeding with pots',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Off: fully random. On: the top clubs in the standings '
                    'go in Pot 1 and never meet each other in that round',
                  ),
                  value: _seeded,
                  onChanged: (v) => setState(() => _seeded = v),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _save(chosen, bracketFrom),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(gala
                      ? 'Save and go to the draw'
                      : 'Save and go to the first draw'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: gala ? 'New gala' : 'New cup',
        subtitle: 'Competitions',
        leading: const CloseButton(),
      ),
      body: body,
    );
  }
}

/// "18 teams · Every approved Division team", opening to tick teams in or
/// out.
class _TeamsCard extends StatelessWidget {
  const _TeamsCard({
    required this.sides,
    required this.left,
    required this.suspended,
    required this.who,
    required this.group,
    required this.onChanged,
  });

  final List<_Side> sides;
  final Set<String> left;
  final Set<String> suspended;
  final CupWho who;
  final AgeGroup group;
  final void Function(String key, bool isIn) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inCount = sides.where((s) => !left.contains(s.entry.key)).length;
    final out = sides.length - inCount;
    final every = switch (who) {
      CupWho.division => 'Every approved Division team',
      CupWho.juvenile => 'Every approved juvenile club (${group.label})',
      CupWho.open => 'Every approved Division team and ${group.label} side',
    };
    return DashboardCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          leading: const Icon(Icons.groups_outlined),
          title: Text(
            '$inCount teams',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            out == 0
                ? every
                : '$out ${out == 1 ? 'team' : 'teams'} left out',
          ),
          trailing: Text(
            'Change',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          children: [
            if (sides.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text('No approved teams in this competition yet.'),
              ),
            for (final s in sides)
              CheckboxListTile(
                value: !left.contains(s.entry.key),
                title: Text(
                  who == CupWho.open &&
                          s.entry.category == Competition.juvenile
                      ? '${s.name} · ${group.label}'
                      : s.name,
                ),
                subtitle: suspended.contains(s.entry.teamId)
                    ? const Text('Suspended')
                    : null,
                onChanged: (v) => onChanged(s.entry.key, v == true),
              ),
          ],
        ),
      ),
    );
  }
}

/// A format to pick, with what it means (C2).
class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.title,
    required this.text,
    required this.selected,
    required this.onTap,
    this.suggested = false,
  });

  final String title;
  final String text;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AccentTone.blue.background(isDark)
            : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          if (suggested)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00703F),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                'Suggested',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gala's timetable, worked out as the FA types (C2b "The plan").
class _GalaPlanCard extends StatelessWidget {
  const _GalaPlanCard({required this.plan, required this.rest});

  final GalaPlan plan;
  final String rest;

  /// "Sat 9:00 am – 1:30 pm", "Sat 3:00 pm – Sun 10:30 am" or "Sun 4:00 pm"
  static String _when(List<DateTime> times) {
    final first = times.first;
    final last = times.last;
    final day = formatShortDate(first).split(' ').first;
    if (times.length == 1) return '$day ${formatTime(first)}';
    final sameDay = first.day == last.day && first.month == last.month;
    final lastDay = formatShortDate(last).split(' ').first;
    return '$day ${formatTime(first)} – '
        '${sameDay ? '' : '$lastDay '}${formatTime(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardSectionTitle(
          title: 'The plan',
          trailing: 'Straight knockout',
        ),
        DashboardCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            children: [
              for (final r in plan.rounds)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          r.byes > 0
                              ? '${r.name} (${r.teams} teams, ${r.byes} byes)'
                              : r.name,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            // The final shows only its kick-off
                            if (r.teams > 2) '${r.teams ~/ 2} matches',
                            r.kickoffs.length < r.teams ~/ 2
                                ? "Doesn't fit"
                                : _when(r.kickoffs),
                          ].join(' · '),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: r.kickoffs.length < r.teams ~/ 2
                                ? AccentTone.red.foreground(isDark)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (!plan.fits)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccentTone.gold.background(isDark),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AccentTone.gold.foreground(isDark),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Not every match fits in these days. Add a day, start '
                    'earlier or shorten the time between kick-offs.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Text(
          'One match per tie. A club gets at least $rest rest between its '
          "matches; the app warns when it can't. Last kick-off 4:30 pm.",
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// A tappable field that shows a value (a date or a time).
class _PickField extends StatelessWidget {
  const _PickField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: Icon(icon)),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
