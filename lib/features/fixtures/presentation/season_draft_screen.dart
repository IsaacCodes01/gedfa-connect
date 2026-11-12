import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
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
import 'package:gedfa_connect/features/fixtures/data/season_maker.dart';
import 'package:gedfa_connect/features/fixtures/domain/season_plan.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:go_router/go_router.dart';

/// FA: the draft season (3.0b, mockup G2). The summary, anything to look
/// at, then every matchday. Tap a match to swap home and away or change
/// its date, time or ground. "Publish and tell all teams" saves the
/// matches; "Save the draft for later" keeps it for the FA only.
class SeasonDraftScreen extends ConsumerStatefulWidget {
  const SeasonDraftScreen({super.key});

  @override
  ConsumerState<SeasonDraftScreen> createState() => _SeasonDraftScreenState();
}

class _SeasonDraftScreenState extends ConsumerState<SeasonDraftScreen> {
  bool _busy = false;

  Future<void> _shuffle() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Draw again?'),
        content: const Text(
          'A new random draw with the same settings. Changes you made to '
          'this draft are lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep this draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Draw again'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(seasonMakerProvider.notifier).shuffle();
  }

  Future<void> _save(SeasonSession s) async {
    final me = ref.read(authRepositoryProvider).currentUser;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(fixtureRepositoryProvider)
          .saveDraft(
            draftId: s.draftId,
            category: s.category,
            ageGroup: s.group,
            settings: s.settings,
            teamIds: [for (final t in s.teams) t.side.id],
            matches: s.draft.matches,
            by: me,
          );
      if (!mounted) return;
      AppToast.success(
        context,
        'Draft saved. Continue it from Make the season.',
      );
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish(SeasonSession s) async {
    final me = ref.read(authRepositoryProvider).currentUser;
    if (me == null) return;
    final kitProblems = s.kitProblems;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Publish ${s.draft.matches.length} matches?'),
        content: Text(
          'Every team in the ${s.leagueName} is told and sees its matches.'
          '${kitProblems == 0 ? '' : '\n\n$kitProblems matches have a kit clash the app '
                    "couldn't solve: choose their kits after publishing (tap the "
                    'match, then Kits).'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // S2 (M2): the sheet with the progress bar while the matches go out
      await SendingSheet.run(
        context,
        title: 'Publishing the season…',
        unit: 'Match',
        task: (progress) => ref
            .read(fixtureRepositoryProvider)
            .publishSeason(
              draftId: s.draftId,
              leagueName: s.leagueName,
              matches: s.toFixtureDrafts(),
              by: me,
              onProgress: progress,
            ),
      );
      if (!mounted) return;
      ref.read(seasonMakerProvider.notifier).clear();
      AppToast.success(context, 'Season published. Every team was told.');
      context.go(Routes.adminFixtures);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        '${appErrorMessage(error)} Tap Publish again: it carries on where it '
        'stopped.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(SeasonSession s, DraftMatch m) async {
    final updated = await showModalBottomSheet<DraftMatch>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditMatchSheet(session: s, match: m),
    );
    if (updated != null) {
      ref.read(seasonMakerProvider.notifier).replace(m, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(seasonMakerProvider);
    if (s == null) {
      return const Scaffold(
        body: EmptyView(
          icon: Icons.auto_awesome_outlined,
          title: 'No draft',
          message: 'Go back and tap Make the draft.',
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final byRound = <int, List<DraftMatch>>{};
    for (final m in s.draft.matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final rounds = byRound.keys.toList()..sort();
    final last = s.draft.lastDay;
    final kitProblems = s.kitProblems;

    final header = <Widget>[
      DashboardCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _Sum('${s.draft.rounds}', 'matchdays'),
            _Sum('${s.draft.matches.length}', 'matches'),
            _Sum(
              last == null ? '–' : formatShortDate(last).split(' ').last,
              last == null ? 'last one' : 'last one, ${last.year}',
            ),
          ],
        ),
      ),
      for (final w in [
        ...s.draft.warnings,
        if (kitProblems > 0)
          '$kitProblems matches have a kit clash the app could not solve. '
              'Choose their kits after publishing.',
      ]) ...[
        const SizedBox(height: 10),
        DashboardCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AccentTone.gold.foreground(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(w, style: const TextStyle(fontSize: 12.5))),
            ],
          ),
        ),
      ],
    ];

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Draft season',
        subtitle: '${s.leagueName} · not published',
        actions: [
          IconButton(
            tooltip: 'Draw again',
            onPressed: _busy ? null : _shuffle,
            icon: const Icon(Icons.shuffle),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outline)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : () => _publish(s),
                    child: const Text('Publish and tell all teams'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _save(s),
                    child: const Text('Save the draft for later'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: rounds.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return Column(children: header);
            final round = rounds[i - 1];
            final list = byRound[round]!
              ..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DashboardSectionTitle(
                  title: 'Matchday $round',
                  trailing: _dates(list),
                ),
                FixtureListCard(
                  children: [
                    for (final m in list)
                      _DraftRow(session: s, match: m, onTap: () => _edit(s, m)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _dates(List<DraftMatch> list) {
    final first = formatShortDate(list.first.kickoffAt);
    final last = formatShortDate(list.last.kickoffAt);
    return first == last ? first : '$first – $last';
  }
}

class _Sum extends StatelessWidget {
  const _Sum(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One match of the draft, like a fixture row.
class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.session,
    required this.match,
    required this.onTap,
  });

  final SeasonSession session;
  final DraftMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final home = session.team(match.homeId)?.side;
    final away = session.team(match.awayId)?.side;
    final muted = TextStyle(
      fontSize: 11.5,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (home == null || away == null) return const SizedBox.shrink();

    Widget side(bool isHome) {
      final s = isHome ? home : away;
      final name = Flexible(
        child: Text(
          s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isHome ? TextAlign.start : TextAlign.end,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      );
      return Row(
        mainAxisAlignment: isHome
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: isHome
            ? [FixtureCrest(side: s), const SizedBox(width: 8), name]
            : [name, const SizedBox(width: 8), FixtureCrest(side: s)],
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(formatShortDate(match.kickoffAt), style: muted),
                ),
                Flexible(
                  child: Text(
                    match.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: side(true)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: dashboardTrack(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    formatTime(match.kickoffAt),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: side(false)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Change one match of the draft: swap home and away, date, time, ground.
class _EditMatchSheet extends StatefulWidget {
  const _EditMatchSheet({required this.session, required this.match});

  final SeasonSession session;
  final DraftMatch match;

  @override
  State<_EditMatchSheet> createState() => _EditMatchSheetState();
}

class _EditMatchSheetState extends State<_EditMatchSheet> {
  late DraftMatch _m = widget.match;
  late final _venue = TextEditingController(text: widget.match.venue);

  @override
  void dispose() {
    _venue.dispose();
    super.dispose();
  }

  void _swap() => setState(() {
    final newHome = widget.session.team(_m.awayId);
    _m = _m.copyWith(homeId: _m.awayId, awayId: _m.homeId);
    // The match follows the new home team's ground
    if (newHome != null && newHome.homeGround.isNotEmpty) {
      _venue.text = newHome.homeGround;
    }
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _m.kickoffAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 500)),
      helpText: 'Match date',
    );
    if (picked != null && mounted) {
      setState(
        () => _m = _m.copyWith(
          kickoffAt: DateTime(
            picked.year,
            picked.month,
            picked.day,
            _m.kickoffAt.hour,
            _m.kickoffAt.minute,
          ),
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_m.kickoffAt),
      helpText: 'Kick-off',
    );
    if (picked != null && mounted) {
      final d = _m.kickoffAt;
      setState(
        () => _m = _m.copyWith(
          kickoffAt: DateTime(
            d.year,
            d.month,
            d.day,
            picked.hour,
            picked.minute,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.session.team(_m.homeId)?.side.name ?? '';
    final away = widget.session.team(_m.awayId)?.side.name ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$home v $away',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text('Matchday ${_m.round}'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _swap,
              icon: const Icon(Icons.swap_vert),
              label: const Text('Swap home and away'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(formatShortDate(_m.kickoffAt)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(formatTime(_m.kickoffAt)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _venue,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Venue'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _venue.text.trim().length < 2
                  ? null
                  : () => Navigator.pop(
                      context,
                      _m.copyWith(venue: _venue.text.trim()),
                    ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
