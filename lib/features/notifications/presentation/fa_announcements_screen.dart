import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/announcement.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:go_router/go_router.dart';

/// The teams an announcement is for (empty for referees-only).
List<Team> teamsFor(Audience to, List<Team> teams) => switch (to) {
      Audience.everyone || Audience.teams => teams,
      Audience.division =>
        teams.where((t) => t.categories.contains(Competition.division)).toList(),
      Audience.juvenile =>
        teams.where((t) => t.categories.contains(Competition.juvenile)).toList(),
      Audience.referees => const [],
    };

/// How many can see it: teams, or referees for a referees-only one.
int audienceSize(Audience to, List<Team> teams, int referees) =>
    to == Audience.referees ? referees : teamsFor(to, teams).length;

/// FA, More › Announcements: everything sent, with who has seen it.
class FaAnnouncementsScreen extends ConsumerWidget {
  const FaAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(myAnnouncementsProvider);

    return Scaffold(
      appBar: const GedfaAppBar(
        title: 'Announcements',
        subtitle: 'Gomoa East District FA',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.adminNewAnnouncement),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('New announcement'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (announcements) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            ResponsiveCenter(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Announcements go to the bell of everyone you choose. '
                      'Pinned ones also show on top of their home screen.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (announcements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyView(
                        icon: Icons.campaign_outlined,
                        title: 'No announcements yet',
                        message: 'Tap "New announcement" to send one.',
                      ),
                    )
                  else
                    for (final a in announcements) ...[
                      _AnnouncementCard(announcement: a),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final a = announcement;
    final seen = ref.watch(announcementSeenProvider(a.id)).value ?? const {};
    final teams = ref.watch(allTeamsProvider).value ?? const <Team>[];
    final referees = (ref.watch(membersProvider).value ?? const [])
        .where((m) => m.role == UserRole.referee)
        .length;
    final total = audienceSize(a.to, teams, referees);
    final seenTeams = [
      for (final t in teamsFor(a.to, teams))
        if (seen.containsKey(t.id)) t,
    ];

    Widget chip(String text, Color bg, Color ink) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              color: ink,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        );

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: a.important ? scheme.error : scheme.outline,
          width: a.important ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.go(Routes.adminAnnouncement(a.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  chip(a.to.label, scheme.outline.withValues(alpha: 0.4),
                      scheme.onSurface),
                  if (a.important)
                    chip('Important', scheme.error.withValues(alpha: 0.12),
                        scheme.error),
                  if (a.pinned)
                    chip('Pinned', scheme.primary.withValues(alpha: 0.12),
                        scheme.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                a.title,
                style:
                    textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                a.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Small overlapping logos of the teams who have seen it
                  SizedBox(
                    height: 28,
                    width: seenTeams.isEmpty
                        ? 0
                        : 28 + 18.0 * (seenTeams.take(5).length - 1),
                    child: Stack(
                      children: [
                        for (var i = 0; i < seenTeams.take(5).length; i++)
                          Positioned(
                            left: 18.0 * i,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: scheme.surface, width: 2),
                              ),
                              child: TeamLogo(
                                label: initialsFor(seenTeams[i].name),
                                color: seenTeams[i].logoColor,
                                url: seenTeams[i].logoUrl,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (seenTeams.length > 5) ...[
                    const SizedBox(width: 6),
                    Text(
                      '+${seenTeams.length - 5} more',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'Seen by ${seen.length} of $total',
                    style: textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  a.createdByName,
                  if (a.createdAt != null) formatDateTime(a.createdAt!),
                ].join(' · '),
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
