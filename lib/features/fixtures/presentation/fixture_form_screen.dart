import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/sending.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/kit_clash.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/core/widgets/one_line.dart';

/// FA: "Add one match" (mockup F2) or, with [fixtureId], "Change a match"
/// (E1). The competition is fixed once a match exists; everything else can
/// change. Things that look wrong (a team playing twice on a matchday, a
/// ground already in use that day) are warnings, not blocks.
class FixtureFormScreen extends ConsumerWidget {
  const FixtureFormScreen({
    super.key,
    this.fixtureId,
    this.category = Competition.division,
    this.group,
  });

  final String? fixtureId;

  /// For a new match: the tab the FA came from.
  final Competition category;
  final AgeGroup? group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = fixtureId;
    if (id == null) {
      return _Form(category: category, group: group);
    }
    final fixtureAsync = ref.watch(fixtureProvider(id));
    return fixtureAsync.when(
      loading: () => const Scaffold(body: LoadingView(message: 'Loading the match…')),
      error: (error, _) =>
          Scaffold(body: ErrorView(message: appErrorMessage(error))),
      data: (f) => f == null
          ? const Scaffold(
              body: EmptyView(
                icon: Icons.event_busy_outlined,
                title: 'Match not found',
                message: 'It may have been removed.',
              ),
            )
          : _Form(
              category: f.category,
              group: f.ageGroup,
              existing: f,
            ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.category, this.group, this.existing});

  final Competition category;
  final AgeGroup? group;
  final Fixture? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late Competition _category = widget.category;
  late AgeGroup? _group =
      widget.category == Competition.juvenile ? (widget.group ?? AgeGroup.u17) : null;
  int? _round;
  String? _homeId;
  String? _awayId;
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 15, minute: 0);
  final _venue = TextEditingController();
  final _reason = TextEditingController();

  /// The venue was typed by the FA: don't replace it with the home ground.
  bool _venueTyped = false;
  bool _busy = false;
  bool _showErrors = false;

  bool get _isChange => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    if (f != null) {
      _round = f.round;
      _homeId = f.home.id;
      _awayId = f.away.id;
      final k = f.kickoffAt?.toLocal();
      if (k != null) {
        _date = DateTime(k.year, k.month, k.day);
        _time = TimeOfDay.fromDateTime(k);
      }
      _venue.text = f.venue;
      _venueTyped = true;
    }
  }

  @override
  void dispose() {
    _venue.dispose();
    _reason.dispose();
    super.dispose();
  }

  DateTime? get _kickoff {
    final d = _date;
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, _time.hour, _time.minute);
  }

  /// The same competition (and age group) as this match, this season.
  List<Fixture> _sameCompetition(List<Fixture> all) => [
        for (final f in all)
          if (f.category == _category &&
              f.ageGroup == _group &&
              !f.isCancelled &&
              f.id != widget.existing?.id)
            f,
      ];

  // ---------- Pickers ----------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Default: the coming Saturday
    final saturday =
        today.add(Duration(days: (DateTime.saturday - today.weekday) % 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? saturday,
      firstDate: today,
      lastDate: today.add(const Duration(days: 400)),
      helpText: 'Match date',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Kick-off',
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _swap() => setState(() {
        final h = _homeId;
        _homeId = _awayId;
        _awayId = h;
        _venueTyped = _isChange; // a new match follows the new home ground
      });

  // ---------- Save ----------

  String? _problem(MatchTeam? home, MatchTeam? away) {
    if (_round == null) return 'Choose the matchday';
    if (_homeId == null || _awayId == null) return 'Choose both teams';
    if (_homeId == _awayId) return 'A team cannot play itself';
    final k = _kickoff;
    if (k == null) return 'Pick the date';
    if (!k.isAfter(DateTime.now())) return 'Pick a kick-off in the future';
    if (_venue.text.trim().length < 2) return 'Enter the venue';
    if (home == null || away == null) return 'Loading the teams…';
    if (home.kits[KitSlot.home] == null || away.kits[KitSlot.home] == null) {
      return 'A team has no kits saved; ask it to add them first';
    }
    return null;
  }

  ({KitSlot home, KitSlot away, KitSlot homeGk, KitSlot awayGk}) _slots(
    MatchTeam home,
    MatchTeam away,
    KitPlan plan,
  ) {
    final f = widget.existing;
    // A change with the same teams keeps the FA's kit choices, if the
    // teams still have those kits
    if (f != null && f.home.id == home.side.id && f.away.id == away.side.id) {
      KitSlot keep(MatchTeam t, KitSlot slot, KitSlot planned) =>
          t.kits[slot] != null ? slot : planned;
      return (
        home: keep(home, f.kits.home.slot, plan.home),
        away: keep(away, f.kits.away.slot, plan.away),
        homeGk: keep(home, f.kits.homeGk.slot, plan.homeGk),
        awayGk: keep(away, f.kits.awayGk.slot, plan.awayGk),
      );
    }
    return (
      home: plan.home,
      away: plan.away,
      homeGk: plan.homeGk,
      awayGk: plan.awayGk,
    );
  }

  Future<void> _save(MatchTeam? home, MatchTeam? away, KitPlan? plan) async {
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    final problem = _problem(home, away);
    final me = ref.read(authRepositoryProvider).currentUser;
    if (problem != null || me == null || plan == null) {
      AppToast.warning(context, problem ?? 'Please sign in again.');
      return;
    }
    final draft = FixtureDraft(
      category: _category,
      ageGroup: _group,
      round: _round!,
      home: home!,
      away: away!,
      kickoffAt: _kickoff!,
      venue: _venue.text,
      kits: _slots(home, away, plan),
    );

    setState(() => _busy = true);
    final repo = ref.read(fixtureRepositoryProvider);
    try {
      if (widget.existing case final old?) {
        await repo.change(old, draft, reason: _reason.text, by: me);
      } else {
        await repo.add(draft, by: me);
      }
      if (!mounted) return;
      AppToast.success(
        context,
        _isChange
            ? 'Match saved. The teams were told.'
            : 'Match added. Both teams were told.',
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allTeams = ref.watch(allTeamsProvider).value ?? const <Team>[];
    final allFixtures = ref.watch(seasonFixturesProvider).value ?? const [];
    final same = _sameCompetition(allFixtures);

    // Teams in this competition, A to Z
    final teams = [
      for (final t in allTeams)
        if (t.categories.contains(_category)) t,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final byId = {for (final t in allTeams) t.id: t};

    // A new match: the latest matchday of the competition
    _round ??= same.isEmpty
        ? 1
        : same.map((f) => f.round).reduce((a, b) => a > b ? a : b);

    // Both teams, read fresh (copy for the match, kits)
    MatchTeam? load(String? id) => id == null
        ? null
        : ref.watch(matchTeamProvider((id, _category))).value;
    final home = load(_homeId);
    final away = load(_awayId);

    // A new match gets the home team's ground until the FA types one
    // (after this frame: a text field can't change while it is built)
    if (!_venueTyped && home != null && _venue.text != home.homeGround) {
      final ground = home.homeGround;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_venueTyped) setState(() => _venue.text = ground);
      });
    }

    final plan = home != null && away != null && _homeId != _awayId
        ? planKits(
            home: home.teamKits,
            away: away.teamKits,
            homeName: home.side.name,
            awayName: away.side.name,
          )
        : null;
    final slots = plan == null || home == null || away == null
        ? null
        : _slots(home, away, plan);

    // Warnings (the FA may still save)
    final kickoff = _kickoff;
    final warnings = <String>[
      for (final id in [_homeId, _awayId])
        if (id != null && byId[id]?.isSuspended == true)
          '${byId[id]!.name} is suspended.',
      for (final id in {_homeId, _awayId})
        if (id != null &&
            same.any((f) => f.round == _round && f.hasTeam(id) && !f.isCancelled))
          '${byId[id]?.name ?? 'A team'} already plays on matchday $_round.',
      if (kickoff != null &&
          _venue.text.trim().isNotEmpty &&
          allFixtures.any((f) =>
              f.id != widget.existing?.id &&
              !f.isCancelled &&
              f.kickoffAt != null &&
              f.venue.toLowerCase() == _venue.text.trim().toLowerCase() &&
              _sameDay(f.kickoffAt!, kickoff)))
        '${_venue.text.trim()} already has a match that day.',
    ];

    final problem = _showErrors ? _problem(home, away) : null;
    final due = kickoff?.subtract(Fixture.sheetLead);

    return Scaffold(
      appBar: GedfaAppBar(
        title: _isChange ? 'Change a match' : 'Add one match',
        subtitle: _isChange
            ? '${widget.existing!.competitionLabel} · Matchday '
                '${widget.existing!.round}'
            : 'Fixtures',
        leading: const CloseButton(),
      ),
      bottomNavigationBar: _SaveBar(
        busy: _busy,
        label: _isChange ? 'Save and tell the teams' : 'Save and tell both teams',
        onSave: () => _save(home, away, plan),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Competition: fixed once the match exists (3.0c adds cups)
            if (!_isChange) ...[
              SegmentedButton<Competition>(
                segments: const [
                  ButtonSegment(
                    value: Competition.division,
                    label: Text('Division League'),
                  ),
                  ButtonSegment(
                    value: Competition.juvenile,
                    label: Text('Juvenile League'),
                  ),
                ],
                selected: {_category},
                onSelectionChanged: (v) => setState(() {
                  _category = v.first;
                  _group = _category == Competition.juvenile
                      ? AgeGroup.u17
                      : null;
                  _homeId = null;
                  _awayId = null;
                  _round = null;
                }),
              ),
              if (_category == Competition.juvenile) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final g in AgeGroup.values)
                      ChoiceChip(
                        label: Text(g.label),
                        selected: _group == g,
                        onSelected: (_) => setState(() {
                          _group = g;
                          _round = null;
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<int>(
              initialValue: _round,
              decoration: const InputDecoration(labelText: 'Matchday'),
              items: [
                for (var i = 1; i <= 60; i++)
                  DropdownMenuItem(value: i, child: Text('$i')),
              ],
              onChanged: (v) => setState(() => _round = v),
            ),
            const SizedBox(height: 12),
            _TeamPicker(
              label: 'Home team',
              value: _homeId,
              teams: teams,
              onChanged: (id) => setState(() {
                _homeId = id;
                if (!_isChange) _venueTyped = false;
              }),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextButton.icon(
                  onPressed: _homeId == null && _awayId == null ? null : _swap,
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('Swap home and away'),
                ),
              ),
            ),
            _TeamPicker(
              label: 'Away team',
              value: _awayId,
              teams: teams,
              onChanged: (id) => setState(() => _awayId = id),
            ),
            const SizedBox(height: 6),
            Text(
              'Only approved teams in this competition.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: OneLine(Text(
                      _date == null ? 'Date' : formatShortDate(_date!),
                    )),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_outlined),
                    label: OneLine(Text(_time.format(context))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _venue,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Venue',
                helperText: "The home team's ground. Change it for a neutral "
                    'ground.',
              ),
              onChanged: (_) => setState(() => _venueTyped = true),
            ),
            if (_isChange) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Why (teams see this)',
                  hintText: "e.g. The home team's ground is booked",
                ),
              ),
            ],
            if (due != null) ...[
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.schedule,
                tone: AccentTone.gold,
                text: 'Team sheets due ${formatShortDate(due)}, '
                    '${formatTime(due)} (1 hour before kick-off)',
              ),
            ],
            if (slots != null && home != null && away != null) ...[
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.checkroom,
                tone: plan!.isClear ? AccentTone.green : AccentTone.red,
                text: '${home.side.name}: ${slots.home.label.toLowerCase()}. '
                    '${away.side.name}: ${slots.away.label.toLowerCase()}.'
                    '${[...plan.problems, ...plan.notes].map((p) => ' $p').join()}',
              ),
            ],
            for (final w in warnings) ...[
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.warning_amber_rounded,
                tone: AccentTone.gold,
                text: w,
              ),
            ],
            if (problem != null) ...[
              const SizedBox(height: 12),
              Text(problem, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}

class _TeamPicker extends StatelessWidget {
  const _TeamPicker({
    required this.label,
    required this.value,
    required this.teams,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<Team> teams;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // A new key when the value changes from outside (Swap)
      key: ValueKey('$label-$value'),
      initialValue: teams.any((t) => t.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final t in teams)
          DropdownMenuItem(
            value: t.id,
            child: Text(
              t.isSuspended ? '${t.name} (suspended)' : t.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.tone, required this.text});

  final IconData icon;
  final AccentTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: tone.foreground(isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.busy,
    required this.label,
    required this.onSave,
  });

  final bool busy;
  final String label;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: BusyButton(
                label: label,
                busyLabel: 'Saving and telling the teams…',
                busy: busy,
                onPressed: onSave,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
