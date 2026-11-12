import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/officials/data/officials_repository.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';

/// RD2 (3.5b): Matches. Only my appointments: coming up, then played, each
/// with my place. A match I'm taken off leaves the list (I'm told).
class RefereeMatchesScreen extends ConsumerWidget {
  const RefereeMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final mineAsync = ref.watch(myAppointmentsProvider);
    final fixturesAsync = ref.watch(seasonFixturesProvider);
    final error = mineAsync.error ?? fixturesAsync.error;

    final Widget body;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!mineAsync.hasValue || !fixturesAsync.hasValue) {
      body = const SkeletonList(message: 'Finding your matches…', circle: false);
    } else {
      final list = appointmentsOf(
        user?.uid ?? '',
        mineAsync.requireValue,
        fixturesAsync.requireValue,
        DateTime.now(),
      );
      Widget card(List<Appointment> items, {bool played = false}) =>
          FixtureListCard(
            children: [
              for (final a in items)
                Opacity(
                  opacity: played ? .65 : 1,
                  child: FixtureRow(
                    fixture: a.match,
                    extraTags: [
                      FixtureTag(
                        'You: ${a.place.label}',
                        tone: AccentTone.violet,
                      ),
                    ],
                    onTap: () => context.open(Routes.refereeMatch(a.match.id)),
                  ),
                ),
            ],
          );
      body = list.upcoming.isEmpty && list.played.isEmpty
          ? const EmptyView(
              icon: Icons.sports_outlined,
              title: 'No appointments yet',
              message:
                  'When the FA appoints you to a match, it shows here and '
                  'in your bell.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
              children: [
                ResponsiveCenter(
                  maxWidth: 720,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (list.upcoming.isNotEmpty) ...[
                        DashboardSectionTitle(
                          title: 'Coming up',
                          trailing: '${list.upcoming.length}',
                        ),
                        card(list.upcoming),
                      ],
                      if (list.played.isNotEmpty) ...[
                        DashboardSectionTitle(
                          title: 'Played',
                          trailing: '${list.played.length}',
                        ),
                        card(list.played, played: true),
                      ],
                    ],
                  ),
                ),
              ],
            );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Matches',
        subtitle: [
          if ((user?.displayName ?? '').isNotEmpty) user!.displayName!,
          'Referee',
        ].join(' · '),
        actions: const [NotificationBell()],
      ),
      body: body,
    );
  }
}
