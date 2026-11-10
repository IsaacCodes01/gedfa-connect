import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/dashboard/domain/team_home.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/glance_tiles.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/team_home_widgets.dart';
import 'package:gedfa_connect/features/notifications/domain/announcement.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';

/// The team's Home, second part (TDb, mockup td-team-dashboard TD1–TD4):
/// Squad at a glance, Season fee and From GEDFA.

/// Four tiles: Division players (of the squad limit), Match-ready (of the
/// matchday squad; "Can play" from `minPlayers`), Juvenile players by age
/// group, Matches this season. Two by two on a phone, 4 in a row wider.
class TeamGlanceTiles extends StatelessWidget {
  const TeamGlanceTiles({
    super.key,
    required this.glance,
    required this.ready,
    required this.readyGroup,
    required this.maxSquad,
    required this.inDivision,
    required this.inJuvenile,
    required this.juvenileGroups,
    required this.nextKickoff,
    required this.wide,
    required this.onSquad,
    required this.onJuvenile,
    required this.onFixtures,
  });

  final SquadGlance glance;
  final SquadReadiness ready;

  /// The juvenile age group on the Match-ready tile (juvenile-only clubs).
  final AgeGroup? readyGroup;
  final int maxSquad;
  final bool inDivision;
  final bool inJuvenile;
  final List<AgeGroup> juvenileGroups;
  final DateTime? nextKickoff;
  final bool wide;
  final VoidCallback onSquad;

  /// Juvenile tile: the Squad, or (not in Juvenile) Team profile to ask.
  final VoidCallback onJuvenile;
  final VoidCallback onFixtures;

  @override
  Widget build(BuildContext context) {
    final g = glance;
    final r = ready;
    final divisionParts = [
      '${g.divisionApproved} approved',
      if (g.divisionWaiting > 0) '${g.divisionWaiting} waiting',
      if (g.divisionSentBack > 0) '${g.divisionSentBack} sent back',
    ];
    final next = nextKickoff;

    final tiles = [
      inDivision
          ? GlanceTile(
              icon: Icons.groups_rounded,
              tone: AccentTone.blue,
              value: g.division,
              suffix: '/ $maxSquad',
              label: 'Division players',
              progress: maxSquad == 0 ? 0 : g.division / maxSquad,
              progressColors: const [Color(0xFF1259A8), Color(0xFF4FA3F7)],
              detail: divisionParts.join(' · '),
              onTap: onSquad,
            )
          : GlanceTile(
              icon: Icons.groups_rounded,
              tone: AccentTone.blue,
              value: 0,
              valueText: '—',
              label: 'Division players',
              detail: 'Not in the Division · ask in Team profile',
              onTap: onJuvenile,
            ),
      GlanceTile(
        icon: Icons.how_to_reg_rounded,
        tone: r.isFull
            ? AccentTone.green
            : r.canPlay
            ? AccentTone.gold
            : AccentTone.red,
        value: r.approved,
        suffix: '/ ${r.full}',
        label: readyGroup == null
            ? 'Match-ready'
            : 'Match-ready (${readyGroup!.label})',
        progress: r.full == 0 ? 0 : r.approved / r.full,
        progressColors: r.isFull
            ? const [AppColors.ghanaGreen, Color(0xFF2FB67A)]
            : r.canPlay
            ? const [Color(0xFFC99700), AppColors.ghanaGold]
            : const [Color(0xFFB3122A), Color(0xFFFF6B78)],
        detail: r.isFull
            ? 'Full matchday squad ✓'
            : r.canPlay
            ? 'Can play ✓ · ${r.missing} more for a full squad'
            : "Can't play yet · ${r.missingToPlay} more to play",
        onTap: onSquad,
      ),
      inJuvenile
          ? GlanceTile(
              icon: Icons.child_care_rounded,
              tone: AccentTone.violet,
              value: g.juvenile,
              label: 'Juvenile',
              detail: [
                for (final group in juvenileGroups)
                  '${group.label} ${g.juvenileByGroup[group] ?? 0}',
              ].join(' · '),
              onTap: onSquad,
            )
          : GlanceTile(
              icon: Icons.child_care_rounded,
              tone: AccentTone.violet,
              value: 0,
              valueText: '—',
              label: 'Juvenile',
              detail: 'Not in Juvenile · ask in Team profile',
              onTap: onJuvenile,
            ),
      GlanceTile(
        icon: Icons.event_rounded,
        tone: AccentTone.green,
        value: g.matches,
        label: 'Matches this season',
        progress: g.matches == 0 ? 0 : g.played / g.matches,
        progressColors: const [AppColors.ghanaGreen, Color(0xFF2FB67A)],
        detail: g.matches == 0
            ? 'Season not published yet'
            : '${g.played} played'
                  '${next == null ? '' : ' · next ${formatShortDate(next)}'}',
        onTap: onFixtures,
      ),
    ];

    Widget row(List<Widget> items) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: wide ? 16 : 10),
          Expanded(child: items[i]),
        ],
      ],
    );

    if (wide) return row(tiles);
    return Column(
      children: [
        row(tiles.sublist(0, 2)),
        const SizedBox(height: 10),
        row(tiles.sublist(2)),
      ],
    );
  }
}

/// Season fee (TD1–TD3): paid of the fee, a bar, what is left or "Paid in
/// full", payments waiting for the FA, then Add payment and History.
class TeamFeeCard extends StatelessWidget {
  const TeamFeeCard({
    super.key,
    required this.summary,
    required this.waiting,
    required this.onAdd,
    required this.onHistory,
  });

  final FeeSummary summary;

  /// Payments the team added that the FA has not confirmed yet.
  final List<Payment> waiting;
  final VoidCallback onAdd;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final waitingTotal = waiting.fold<int>(0, (t, p) => t + (p.amount ?? 0));
    final note = s.isPaid
        ? 'Thank you! Your season fee is paid.'
        : waiting.isNotEmpty
        ? '${waiting.length == 1 ? '1 payment' : '${waiting.length} payments'}'
              '${waitingTotal > 0 ? ' of ${cedis(waitingTotal)}' : ''} '
              '${waiting.length == 1 ? 'is' : 'are'} waiting for the FA to '
              'confirm.'
        : !s.hasStarted
        ? 'Pay by Mobile Money or at the FA office, then add the payment here.'
        : 'Pay the rest by Mobile Money or at the FA office.';

    return DashboardCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      text: cedis(s.confirmed),
                      children: [
                        TextSpan(
                          text: ' of ${cedis(s.fee)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              s.isPaid
                  ? const HomeChip('Paid in full', tone: AccentTone.green)
                  : HomeChip(
                      '${cedis(s.left)} left',
                      tone: s.hasStarted ? AccentTone.gold : AccentTone.red,
                    ),
            ],
          ),
          const SizedBox(height: 10),
          GrowingBar(
            fraction: s.progress,
            colors: s.isPaid
                ? const [AppColors.ghanaGreen, Color(0xFF2FB67A)]
                : const [Color(0xFFC99700), AppColors.ghanaGold],
          ),
          const SizedBox(height: 8),
          Text(note, style: TextStyle(fontSize: 12, color: muted)),
          if (!s.isPaid) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: s.hasStarted || waiting.isNotEmpty
                      ? FilledButton.tonal(
                          onPressed: onAdd,
                          child: const Text('Add payment'),
                        )
                      : FilledButton(
                          onPressed: onAdd,
                          child: const Text('Add payment'),
                        ),
                ),
                if (s.hasStarted || waiting.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: onHistory,
                      child: const Text('History'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// From GEDFA: the pinned announcement (if any), then the unread notes
/// row that opens the bell.
class FromGedfaCard extends StatelessWidget {
  const FromGedfaCard({
    super.key,
    required this.pinned,
    required this.unread,
    required this.latestUnread,
    required this.onPinned,
    required this.onBell,
  });

  final Announcement? pinned;
  final int unread;

  /// The newest unread note's title, if any.
  final String? latestUnread;
  final VoidCallback onPinned;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final a = pinned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (a != null) ...[
          DashboardCard(
            onTap: onPinned,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AccentIcon(
                  icon: Icons.push_pin_rounded,
                  tone: AccentTone.gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        a.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (a.important)
                            const HomeChip('Important', tone: AccentTone.red),
                          Text(
                            [
                              'Pinned',
                              if (a.createdAt case final at?)
                                formatDayMonth(at),
                            ].join(' · '),
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        TeamNeedsCard(
          rows: [
            TeamNeedRow(
              icon: Icons.notifications_rounded,
              tone: unread == 0 ? AccentTone.grey : AccentTone.blue,
              label: switch (unread) {
                0 => 'No unread notes',
                1 => '1 unread note',
                _ => '$unread unread notes',
              },
              detail: latestUnread == null
                  ? 'Your notes stay in the bell'
                  : 'Latest: "$latestUnread"',
              onTap: onBell,
            ),
          ],
        ),
      ],
    );
  }
}

/// The team's "Coming later" boxes (after match reports, Phase 4).
const teamComingLater = [
  (
    Icons.leaderboard_outlined,
    'Results and table',
    'Your position, form W D L',
  ),
  (Icons.style_outlined, 'Cards and suspensions', 'Who misses the next match'),
  (Icons.sports_outlined, 'Top scorers', 'Goals and assists'),
  (Icons.timer_outlined, 'Season so far', 'Played, won, goals'),
];
