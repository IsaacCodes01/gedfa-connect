import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/team_home_cards.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/officials/data/officials_repository.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';

/// RD1 (3.5b): the referee's Home. Next appointment (my place, kick-off,
/// venue, kits and a referee colour that doesn't clash, the other
/// officials, when the team sheets open), coming up, Needs you, From
/// GEDFA.
class RefereeHomeScreen extends ConsumerWidget {
  const RefereeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final uid = user?.uid ?? '';
    final now = DateTime.now();
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final mine = ref.watch(myAppointmentsProvider).value ?? const {};
    final fixtures = ref.watch(seasonFixturesProvider).value ?? const [];
    final list = appointmentsOf(uid, mine, fixtures, now);
    final next = list.upcoming.firstOrNull;
    final later = list.upcoming.skip(1).take(3).toList();
    final name = (user?.displayName ?? '').trim();

    // Match day: today's appointments (the sheets open at the lock)
    final today = [
      for (final a in list.upcoming)
        if (a.match.kickoffAt case final k?
            when k.toLocal().year == now.year &&
                k.toLocal().month == now.month &&
                k.toLocal().day == now.day)
          a,
    ];

    final content = <Widget>[
      DashboardSectionTitle(
        title: 'Next appointment',
        trailing: list.upcoming.isEmpty ? null : 'All ›',
        onTap: list.upcoming.isEmpty
            ? null
            : () => context.open(Routes.refereeMatches),
        top: 2,
      ),
      if (next == null)
        const _NoAppointment()
      else
        NextAppointmentCard(appointment: next, uid: uid),
      if (later.isNotEmpty) ...[
        const SizedBox(height: 10),
        FixtureListCard(
          children: [
            for (final a in later)
              FixtureRow(
                fixture: a.match,
                extraTags: [
                  FixtureTag('You: ${a.place.label}', tone: AccentTone.violet),
                ],
                onTap: () => context.open(Routes.refereeMatch(a.match.id)),
              ),
          ],
        ),
      ],
      const DashboardSectionTitle(title: 'Needs you'),
      if (today.isEmpty)
        const _CaughtUp()
      else
        DashboardCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final a in today)
                ListTile(
                  leading: Icon(
                    Icons.sports_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    'Match today: ${a.match.home.shortName} v '
                    '${a.match.away.shortName}',
                  ),
                  subtitle: Text(
                    'You: ${a.place.label} · ${formatTime(a.match.kickoffAt!)}'
                    ' · team sheets open at '
                    '${formatTime(a.match.sheetDueAt!)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.open(Routes.refereeMatch(a.match.id)),
                ),
            ],
          ),
        ),
      const DashboardSectionTitle(title: 'From GEDFA'),
      _FromGedfa(),
    ];

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          DashboardHeader(
            wide: wide,
            label: 'GEDFA CONNECT · REFEREE',
            crest: CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF0F1B2D),
              child: Text(
                name.isEmpty ? 'R' : initialsFor(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            subtitle: 'Referee · GEDFA · ${formatShortDate(now)}',
            tags: [
              HeaderTag(label: 'Season ${Season.label(Season.current)}'),
              HeaderTag(
                open: list.upcoming.isNotEmpty,
                label: list.upcoming.length == 1
                    ? '1 appointment'
                    : '${list.upcoming.length} appointments',
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, wide ? 22 : 16, 14, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The next appointment (RD1): my place, both sides, kick-off, venue,
/// kits and the referee colours, the other officials, the sheets' time.
class NextAppointmentCard extends StatelessWidget {
  const NextAppointmentCard({
    super.key,
    required this.appointment,
    required this.uid,
  });

  final Appointment appointment;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final f = appointment.match;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final kickoff = f.kickoffAt;
    final colours = refereeColoursFor(f);
    final others = othersLine(appointment.officials, uid);

    Widget side(FixtureSide s, String where) => Expanded(
      child: Column(
        children: [
          FixtureCrest(side: s, size: 50),
          const SizedBox(height: 5),
          Text(
            s.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          Text(where, style: TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );

    Widget fact(IconData icon, Widget text) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 9),
          Expanded(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 12.5),
              child: text,
            ),
          ),
        ],
      ),
    );

    return DashboardCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${f.competitionLabel} · Matchday ${f.round}'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: .3,
                  ),
                ),
              ),
              FixtureTag(
                'You: ${appointment.place.label}',
                tone: AccentTone.violet,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              side(f.home, 'Home'),
              Column(
                children: [
                  Text(
                    kickoff == null ? 'TBC' : formatTime(kickoff),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    kickoff == null ? 'Postponed' : formatShortDate(kickoff),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ],
              ),
              side(f.away, 'Away'),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 14, color: dashboardBorder(context)),
          fact(Icons.location_on_outlined, Text(f.venue)),
          fact(
            Icons.checkroom_outlined,
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                const Text('Kits:'),
                _Kit(f.kits.home.kit.primary),
                const Text('v'),
                _Kit(f.kits.away.kit.primary),
                if (colours.isNotEmpty)
                  Text(
                    '· wear ${[for (final c in colours.take(2)) c.$1].join(' or ')}',
                  ),
              ],
            ),
          ),
          if (others.isNotEmpty)
            fact(Icons.groups_outlined, Text('With: $others')),
          if (f.sheetDueAt case final due?)
            fact(
              Icons.lock_clock_outlined,
              Text('Team sheets open to you at ${formatTime(due)}'),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.open(Routes.refereeMatch(f.id)),
            child: const Text('Match details'),
          ),
        ],
      ),
    );
  }
}

class _Kit extends StatelessWidget {
  const _Kit(this.colour);

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 18,
    decoration: BoxDecoration(
      color: colour,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.black26),
    ),
  );
}

class _NoAppointment extends StatelessWidget {
  const _NoAppointment();

  @override
  Widget build(BuildContext context) => DashboardCard(
    padding: const EdgeInsets.all(18),
    child: Text(
      'No appointments yet. When the FA appoints you to a match, it shows '
      'here and in your bell.',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 28,
            color: AccentTone.green.foreground(isDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All caught up',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  'On match day your match shows here. Match reports come '
                  'with Phase 4.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Announcements to referees, as on the team's Home (TDb).
class _FromGedfa extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(pinnedAnnouncementProvider);
    final mark = ref.watch(readMarkProvider).value;
    final notes = ref.watch(myNotificationsProvider).value ?? const [];
    final latest = mark == null
        ? null
        : notes.where((n) => mark.isUnread(n.id, n.updatedAt)).firstOrNull;
    return FromGedfaCard(
      pinned: pinned,
      unread: ref.watch(unreadCountProvider),
      latestUnread: latest?.title,
      onPinned: () => context.open(Routes.refereeAnnouncement(pinned!.id)),
      onBell: () => context.open(Routes.refereeNotifications),
    );
  }
}
