import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/season_maker.dart';
import 'package:gedfa_connect/features/fixtures/domain/season_plan.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/core/widgets/one_line.dart';

/// FA: "Make the season" (3.0b, mockup G1). Pick the teams, home and away
/// or once, the first matchday, match days, kick-off and weeks off; the
/// app draws a round robin and shows the draft (G2). Nothing is sent to
/// teams until the FA publishes. Juvenile: one age group at a time.
class SeasonSetupScreen extends ConsumerStatefulWidget {
  const SeasonSetupScreen({super.key, this.category = Competition.division});

  final Competition category;

  @override
  ConsumerState<SeasonSetupScreen> createState() => _SeasonSetupScreenState();
}

class _SeasonSetupScreenState extends ConsumerState<SeasonSetupScreen> {
  late Competition _category = widget.category;
  late AgeGroup? _group =
      widget.category == Competition.juvenile ? AgeGroup.u17 : null;

  /// Teams left out of the draw (all are in by default).
  final _left = <String>{};
  bool _homeAndAway = true;
  bool _sundayToo = true;
  late DateTime _firstDay = _nextSaturday();
  TimeOfDay _kickoff = const TimeOfDay(hour: 15, minute: 0);
  final _weeksOff = <WeekOff>[];

  static DateTime _nextSaturday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = (DateTime.saturday - today.weekday) % 7;
    return today.add(Duration(days: days == 0 ? 7 : days));
  }

  void _setCategory(Competition c) => setState(() {
        _category = c;
        _group = c == Competition.juvenile ? AgeGroup.u17 : null;
        _left.clear();
        _kickoff = c == Competition.juvenile
            ? const TimeOfDay(hour: 9, minute: 0)
            : const TimeOfDay(hour: 15, minute: 0);
      });

  Future<void> _pickFirstDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDay,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 400)),
      helpText: 'First matchday',
    );
    if (picked != null && mounted) setState(() => _firstDay = picked);
  }

  Future<void> _pickKickoff() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _kickoff,
      helpText: 'Kick-off',
    );
    if (picked != null && mounted) setState(() => _kickoff = picked);
  }

  Future<void> _addWeekOff() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 400)),
      helpText: 'Weeks with no matches',
    );
    if (picked != null && mounted) {
      setState(() => _weeksOff.add(WeekOff(picked.start, picked.end)));
    }
  }

  /// "Make the draft"
  void _make(List<MatchTeam> teams, int firstRound) {
    final chosen = [
      for (final t in teams)
        if (!_left.contains(t.side.id)) t,
    ];
    if (chosen.length < 2) {
      AppToast.warning(context, 'Choose at least 2 teams.');
      return;
    }
    ref.read(seasonMakerProvider.notifier).make(
          category: _category,
          group: _group,
          teams: chosen,
          firstRound: firstRound,
          settings: SeasonSettings(
            firstDay: _firstDay,
            homeAndAway: _homeAndAway,
            sundayToo: _sundayToo,
            kickoffHour: _kickoff.hour,
            kickoffMinute: _kickoff.minute,
            weeksOff: [..._weeksOff],
          ),
        );
    context.push(Routes.adminSeasonDraft);
  }

  /// "Continue" a saved draft.
  void _continue(Map<String, dynamic> saved, List<MatchTeam> teams) {
    final settings =
        SeasonSettings.fromMap(saved['settings'] as Map<String, dynamic>?);
    final ids = [
      for (final id in saved['teamIds'] as List<dynamic>? ?? const [])
        id.toString(),
    ];
    final chosen = [
      for (final id in ids) ?teams.where((t) => t.side.id == id).firstOrNull,
    ];
    final matches = [
      for (final m in saved['matches'] as List<dynamic>? ?? const [])
        ?DraftMatch.fromMap(m as Map<String, dynamic>?),
    ];
    if (settings == null || matches.isEmpty) {
      AppToast.error(context, 'This draft could not be read. Start again.');
      return;
    }
    ref.read(seasonMakerProvider.notifier).resume(SeasonSession(
          category: _category,
          group: _group,
          teams: chosen,
          settings: settings,
          firstRound: matches.map((m) => m.round).reduce((a, b) => a < b ? a : b),
          draft: SeasonDraft(
            matches: matches,
            warnings: [
              if (chosen.length < ids.length)
                'A team in this draft is no longer approved: its matches '
                    'are left out.',
            ],
          ),
        ));
    context.push(Routes.adminSeasonDraft);
  }

  Future<void> _startAgain(String draftId) async {
    try {
      await ref.read(fixtureRepositoryProvider).deleteDraft(draftId);
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final teamsAsync = ref.watch(seasonTeamsProvider(_category));
    final suspended = {
      for (final t in ref.watch(allTeamsProvider).value ?? const [])
        if (t.isSuspended) t.id,
    };
    final draftId = SeasonSession.draftIdFor(_category, _group);
    final saved = ref.watch(savedDraftProvider(draftId)).value;

    // Matchdays already in this league (made by hand or published before)
    final existing = [
      for (final f in ref.watch(seasonFixturesProvider).value ?? const [])
        if (f.category == _category && f.ageGroup == _group && !f.isCancelled)
          f,
    ];
    final lastRound = existing.isEmpty
        ? 0
        : existing.map((f) => f.round).reduce((a, b) => a > b ? a : b);

    Widget body;
    if (teamsAsync.hasError) {
      body = ErrorView(message: appErrorMessage(teamsAsync.error!));
    } else if (!teamsAsync.hasValue) {
      body = const LoadingView(message: 'Loading the season…');
    } else {
      final teams = teamsAsync.requireValue;
      final inCount = teams.where((t) => !_left.contains(t.side.id)).length;
      final hasSuspended = teams.any((t) => suspended.contains(t.side.id));

      body = ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SegmentedButton<Competition>(
              segments: const [
                ButtonSegment(
                  value: Competition.division,
                  label: Text('Division'),
                ),
                ButtonSegment(
                  value: Competition.juvenile,
                  label: Text('Juvenile'),
                ),
              ],
              selected: {_category},
              onSelectionChanged: (v) => _setCategory(v.first),
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
                      onSelected: (_) => setState(() => _group = g),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Each age group gets its own season.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
            if (saved != null) ...[
              const SizedBox(height: 14),
              _SavedDraftCard(
                saved: saved,
                onContinue: () => _continue(saved, teams),
                onStartAgain: () => _startAgain(draftId),
              ),
            ],
            if (lastRound > 0) ...[
              const SizedBox(height: 14),
              _Note(
                icon: Icons.info_outline,
                tone: AccentTone.blue,
                text: 'This league already has ${existing.length} matches, '
                    'up to matchday $lastRound. The new ones start at '
                    'matchday ${lastRound + 1}.',
              ),
            ],
            DashboardSectionTitle(
              title: 'Teams',
              trailing: '$inCount of ${teams.length}',
            ),
            DashboardCard(
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  shape: const Border(),
                  title: Text(
                    inCount == teams.length
                        ? 'All ${teams.length} ${_category.label} teams'
                        : '$inCount teams (${teams.length - inCount} left out)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: hasSuspended
                      ? const Text('Suspended teams are marked')
                      : null,
                  children: [
                    for (final t in teams)
                      CheckboxListTile(
                        value: !_left.contains(t.side.id),
                        title: Text(t.side.name),
                        subtitle: suspended.contains(t.side.id)
                            ? const Text('Suspended')
                            : null,
                        onChanged: (v) => setState(() => v == true
                            ? _left.remove(t.side.id)
                            : _left.add(t.side.id)),
                      ),
                  ],
                ),
              ),
            ),
            const DashboardSectionTitle(title: 'How they play'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Home and away')),
                ButtonSegment(value: false, label: Text('Once')),
              ],
              selected: {_homeAndAway},
              onSelectionChanged: (v) => setState(() => _homeAndAway = v.first),
            ),
            const SizedBox(height: 6),
            Text(
              _homeAndAway
                  ? 'Every team plays every other team twice: once at home, '
                      'once away.'
                  : 'Every team plays every other team once.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const DashboardSectionTitle(title: 'When'),
            OutlinedButton.icon(
              onPressed: _pickFirstDay,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('First matchday: ${formatShortDate(_firstDay)}'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Sat and Sun')),
                      ButtonSegment(value: false, label: Text('Sat only')),
                    ],
                    selected: {_sundayToo},
                    onSelectionChanged: (v) =>
                        setState(() => _sundayToo = v.first),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  // The theme's buttons are full-width; in a row that
                  // breaks the layout
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _pickKickoff,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(_kickoff.format(context)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DashboardCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Weeks with no matches',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addWeekOff,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  if (_weeksOff.isEmpty)
                    Text(
                      'None. Add Christmas, Easter or other breaks.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final w in _weeksOff)
                        InputChip(
                          label: Text('${formatShortDate(w.start)} – '
                              '${formatShortDate(w.end)}'),
                          onDeleted: () =>
                              setState(() => _weeksOff.remove(w)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _make(teams, lastRound + 1),
              child: const Text('Make the draft'),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing is sent to teams until you publish.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: const GedfaAppBar(
        title: 'Make the season',
        subtitle: 'Fixtures',
        leading: CloseButton(),
      ),
      body: body,
    );
  }
}

class _SavedDraftCard extends StatelessWidget {
  const _SavedDraftCard({
    required this.saved,
    required this.onContinue,
    required this.onStartAgain,
  });

  final Map<String, dynamic> saved;
  final VoidCallback onContinue;
  final VoidCallback onStartAgain;

  @override
  Widget build(BuildContext context) {
    final count = (saved['matches'] as List<dynamic>? ?? const []).length;
    final at = (saved['updatedAt'] as Timestamp?)?.toDate();
    return DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A saved draft',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          Text(
            '$count matches${at == null ? '' : ', saved ${formatShortDate(at)}'}. '
            'Not published yet.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onStartAgain,
                  child: const OneLine(Text('Start again')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onContinue,
                  child: const OneLine(Text('Continue')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.tone, required this.text});

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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}
