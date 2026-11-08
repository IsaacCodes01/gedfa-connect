import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_actions.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:go_router/go_router.dart';

/// FA: the Fixtures tab (3.0a, mockup F1 and F3). Division | Juvenile,
/// U13 / U15 / U17 chips for juvenile, matches by matchday, then the
/// postponed and cancelled ones. Tap a match to change, postpone or cancel
/// it. "Add a match" for one match at a time.
class FaFixturesScreen extends ConsumerStatefulWidget {
  const FaFixturesScreen({super.key});

  @override
  ConsumerState<FaFixturesScreen> createState() => _FaFixturesScreenState();
}

class _FaFixturesScreenState extends ConsumerState<FaFixturesScreen> {
  Competition _category = Competition.division;

  /// Juvenile only; null = all three age groups.
  AgeGroup? _group;

  @override
  Widget build(BuildContext context) {
    final fixturesAsync = ref.watch(seasonFixturesProvider);
    final juvenile = _category == Competition.juvenile;

    return Scaffold(
      appBar: const GedfaAppBar(
        title: 'Fixtures',
        subtitle: 'Gomoa East District FA',
        actions: [NotificationBell()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          Uri(path: Routes.adminNewFixture, queryParameters: {
            'category': _category.name,
            'group': ?_group?.label,
          }).toString(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add a match'),
      ),
      body: fixturesAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: appErrorMessage(error),
          onRetry: () => ref.invalidate(seasonFixturesProvider),
        ),
        data: (all) {
          final shown = [
            for (final f in all)
              if (f.category == _category &&
                  (!juvenile || _group == null || f.ageGroup == _group))
                f,
          ];
          return ResponsiveCenter(
            maxWidth: 720,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
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
                  onSelectionChanged: (v) => setState(() {
                    _category = v.first;
                    _group = null;
                  }),
                ),
                if (juvenile) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _group == null,
                        onSelected: (_) => setState(() => _group = null),
                      ),
                      for (final g in AgeGroup.values)
                        ChoiceChip(
                          label: Text(g.label),
                          selected: _group == g,
                          onSelected: (_) => setState(() => _group = g),
                        ),
                    ],
                  ),
                ],
                ..._sections(shown, juvenile),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sections(List<Fixture> shown, bool juvenile) {
    if (shown.isEmpty) {
      return const [
        SizedBox(height: 48),
        EmptyView(
          icon: Icons.calendar_month_outlined,
          title: 'No matches yet',
          message: 'Tap "Add a match" to add the first one.',
        ),
      ];
    }

    Widget row(Fixture f) => FixtureRow(
          fixture: f,
          showJuvenileRules: juvenile,
          onTap: () => showFixtureActions(context, ref, f),
        );

    // Scheduled matches by matchday, each in kick-off order
    final byRound = <int, List<Fixture>>{};
    for (final f in shown.where((f) => f.isScheduled)) {
      byRound.putIfAbsent(f.round, () => []).add(f);
    }
    final rounds = byRound.keys.toList()..sort();
    final postponed = shown.where((f) => f.isPostponed).toList();
    final cancelled = shown.where((f) => f.isCancelled).toList();

    return [
      for (final round in rounds) ...[
        DashboardSectionTitle(
          title: 'Matchday $round',
          trailing: _dates(byRound[round]!),
        ),
        FixtureListCard(
          children: [
            for (final f in byRound[round]!
              ..sort((a, b) => a.kickoffAt!.compareTo(b.kickoffAt!)))
              row(f),
          ],
        ),
      ],
      if (postponed.isNotEmpty) ...[
        DashboardSectionTitle(
          title: 'Postponed',
          trailing: '${postponed.length}',
        ),
        FixtureListCard(children: [for (final f in postponed) row(f)]),
      ],
      if (cancelled.isNotEmpty) ...[
        const DashboardSectionTitle(title: 'Cancelled'),
        FixtureListCard(children: [for (final f in cancelled) row(f)]),
      ],
    ];
  }

  /// "Sat 14 Nov" or "Sat 14 – Sun 15 Nov"
  static String _dates(List<Fixture> list) {
    final days = [for (final f in list) f.kickoffAt!]..sort();
    final first = formatShortDate(days.first);
    final last = formatShortDate(days.last);
    if (first == last) return first;
    final a = first.split(' ');
    final b = last.split(' ');
    // Same month: "Sat 14 – Sun 15 Nov"
    return a.last == b.last ? '${a[0]} ${a[1]} – $last' : '$first – $last';
  }
}
