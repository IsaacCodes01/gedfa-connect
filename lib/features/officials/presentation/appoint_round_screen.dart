import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/officials/data/officials_repository.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';

/// MO3 (3.5a): a whole matchday at once. Every match of the matchday with
/// its five places, so the FA fills the weekend in one go (Isaac: "the FA
/// appoints the referees for each matchday"). A tap opens the match's
/// officials (MO1).
class AppointRoundScreen extends ConsumerWidget {
  const AppointRoundScreen({
    super.key,
    required this.competitionId,
    required this.round,
    this.ageGroup,
  });

  final String competitionId;
  final int round;

  /// Juvenile: one age group's matchday ("U15").
  final String? ageGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixturesAsync = ref.watch(seasonFixturesProvider);
    final officialsAsync = ref.watch(seasonOfficialsProvider);
    final error = fixturesAsync.error ?? officialsAsync.error;
    final matches = [
      for (final f in fixturesAsync.value ?? const <Fixture>[])
        if (f.competitionId == competitionId &&
            f.round == round &&
            f.ageGroup?.label == ageGroup &&
            f.isScheduled &&
            f.kickoffAt != null)
          f,
    ]..sort((a, b) => a.kickoffAt!.compareTo(b.kickoffAt!));
    final all = officialsAsync.value ?? const {};
    final total = OfficialPlace.values.length;
    final complete = matches
        .where((f) => (all[f.id]?.count ?? 0) == total)
        .length;
    final category = matches.firstOrNull?.competitionLabel ?? ageGroup;

    final Widget body;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!fixturesAsync.hasValue || !officialsAsync.hasValue) {
      body = const LoadingView();
    } else if (matches.isEmpty) {
      body = const EmptyView(
        icon: Icons.event_busy_outlined,
        title: 'No matches to appoint',
        message: 'This matchday has no scheduled matches.',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          ResponsiveCenter(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(
                      '${matches.length} '
                      '${matches.length == 1 ? 'match' : 'matches'}',
                      AccentTone.grey,
                    ),
                    _Tag('$complete complete', AccentTone.green),
                    if (matches.length > complete)
                      _Tag(
                        '${matches.length - complete} need officials',
                        AccentTone.gold,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final f in matches) ...[
                  _MatchCard(
                    fixture: f,
                    officials: all[f.id] ?? MatchOfficials(fixtureId: f.id),
                  ),
                  const SizedBox(height: 8),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                  child: Text(
                    'Tap a match to fill its five places. Only the referee '
                    'is required. Each person appointed is told, with all '
                    'their matches of the day in one note.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final first = matches.firstOrNull?.kickoffAt;
    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Appoint officials',
        subtitle: [
          ?category,
          'Matchday $round',
          if (first != null) formatShortDate(first),
        ].join(' · '),
        leading: BackButton(
          onPressed: () => context.goBack(Routes.adminFixtures),
        ),
      ),
      body: body,
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.fixture, required this.officials});

  final Fixture fixture;
  final MatchOfficials officials;

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final o = officials;
    final scheme = Theme.of(context).colorScheme;
    final total = OfficialPlace.values.length;
    final done = o.count == total;
    final names = o.count == 0
        ? 'Not appointed'
        : [
            for (final place in OfficialPlace.values)
              '${place == OfficialPlace.referee ? 'Ref' : place.short} '
                  '${o[place]?.name ?? '—'}',
          ].join(' · ');
    return DashboardCard(
      onTap: () => context.open(Routes.adminMatch(f.id)),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${f.home.name} v ${f.away.name}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _Tag(
                done ? '✓ $total of $total' : '${o.count} of $total',
                done
                    ? AccentTone.green
                    : o.hasReferee
                    ? AccentTone.gold
                    : AccentTone.red,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatTime(f.kickoffAt!)} · ${f.venue}',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
          Text(
            names,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.tone);

  final String text;
  final AccentTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tone.background(isDark),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tone.foreground(isDark),
        ),
      ),
    );
  }
}
