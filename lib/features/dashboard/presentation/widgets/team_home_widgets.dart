import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/dashboard/domain/team_home.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/renamed_pill.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_preview.dart';

/// The team's Home (TDa, mockup td-team-dashboard TD1–TD3): its cards.

/// "Division | Juvenile" (clubs in both only): two halves of one card, the
/// chosen one filled blue, each with how many matches it has.
class MatchSwitch extends StatelessWidget {
  const MatchSwitch({
    super.key,
    required this.selected,
    required this.divisionNote,
    required this.juvenileNote,
    required this.onChanged,
  });

  final Competition selected;
  final String divisionNote;
  final String juvenileNote;
  final ValueChanged<Competition> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget half(Competition c, IconData icon, String note) => Expanded(
      child: _SwitchHalf(
        icon: icon,
        label: c.label,
        note: note,
        on: c == selected,
        onTap: () => onChanged(c),
      ),
    );

    return DashboardCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          half(Competition.division, Icons.shield_rounded, divisionNote),
          const SizedBox(width: 6),
          half(Competition.juvenile, Icons.child_care_rounded, juvenileNote),
        ],
      ),
    );
  }
}

class _SwitchHalf extends StatelessWidget {
  const _SwitchHalf({
    required this.icon,
    required this.label,
    required this.note,
    required this.on,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String note;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = on ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: on,
      label: '$label matches, $note',
      excludeSemantics: true,
      child: Material(
        color: on ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 22, color: ink),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: ink),
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

/// Juvenile: "All · U15 · U17" chips under the switch (only the groups
/// the club plays). Null = All.
class AgeGroupChips extends StatelessWidget {
  const AgeGroupChips({
    super.key,
    required this.groups,
    required this.selected,
    required this.onChanged,
  });

  final List<AgeGroup> groups;
  final AgeGroup? selected;
  final ValueChanged<AgeGroup?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    Widget chip(String label, AgeGroup? group) {
      final on = group == selected;
      return Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? AccentTone.gold.background(isDark) : scheme.surface,
          shape: StadiumBorder(
            side: on
                ? BorderSide.none
                : BorderSide(color: dashboardBorder(context)),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onChanged(group),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on
                      ? AccentTone.gold.foreground(isDark)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [chip('All', null), for (final g in groups) chip(g.label, g)],
      ),
    );
  }
}

/// A small pill: "in 4 days" (blue), "Postponed" (gold).
class HomeChip extends StatelessWidget {
  const HomeChip(this.text, {super.key, this.tone = AccentTone.blue});

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
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tone.foreground(isDark),
        ),
      ),
    );
  }
}

/// "NEXT MATCH · DIVISION · ROUND 3" (juvenile: "JUVENILE U15").
String _matchLabel(Fixture f) {
  final group = f.ageGroup;
  final competition = group == null
      ? f.category.label
      : '${f.category.label} ${group.label}';
  return 'Next match · $competition · Round ${f.round}'.toUpperCase();
}

/// The team's next match (TD1, TD2): both crests (ours marked "You"), the
/// kick-off in the middle, the countdown chip, the ground and the kit we
/// wear, the "Previously" pill of a renamed team, then Match details and
/// Kits.
class HomeNextMatchCard extends StatefulWidget {
  const HomeNextMatchCard({
    super.key,
    required this.fixture,
    required this.teamId,
    required this.now,
    required this.onDetails,
    required this.onKits,
  });

  final Fixture fixture;
  final String teamId;
  final DateTime now;
  final VoidCallback onDetails;
  final VoidCallback onKits;

  @override
  State<HomeNextMatchCard> createState() => _HomeNextMatchCardState();
}

class _HomeNextMatchCardState extends State<HomeNextMatchCard> {
  /// The renamed team whose note is open (JSc2), if any
  String? _openTeamId;

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final kickoff = f.kickoffAt!;
    final kit = f.kitOf(widget.teamId);
    final renamed = f.renamedSides;
    final open = renamed.where((r) => r.$1.id == _openTeamId).firstOrNull;

    Widget side(FixtureSide s, String where) {
      final us = s.id == widget.teamId;
      return Column(
        children: [
          FixtureCrest(side: s, size: 56),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: s.name,
              children: [
                if (us)
                  TextSpan(
                    text: ' · You',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          Text(where, style: TextStyle(fontSize: 11, color: muted)),
        ],
      );
    }

    Widget fact(IconData icon, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 9),
          Expanded(child: child),
        ],
      ),
    );

    return DashboardCard(
      onTap: widget.onDetails,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _matchLabel(f),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              HomeChip(countdownLabel(kickoff, widget.now)),
            ],
          ),
          if (renamed.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (s, previous) in renamed)
                    RenamedPill(
                      side: s,
                      previous: previous,
                      open: _openTeamId == s.id,
                      onTap: () => setState(
                        () => _openTeamId = _openTeamId == s.id ? null : s.id,
                      ),
                    ),
                ],
              ),
            ),
          if (open != null)
            RenamedNote(
              side: open.$1,
              previous: open.$2,
              isHome: f.isHome(open.$1.id),
              onClose: () => setState(() => _openTeamId = null),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: side(f.home, 'Home')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Text(
                        formatTime(kickoff),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        formatShortDate(kickoff),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: side(f.away, 'Away')),
              ],
            ),
          ),
          Divider(height: 1, color: dashboardBorder(context)),
          const SizedBox(height: 4),
          fact(
            Icons.location_on_rounded,
            Text(
              f.venue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          fact(
            Icons.checkroom_rounded,
            Row(
              children: [
                const Text('You wear: ', style: TextStyle(fontSize: 12.5)),
                KitPreview(kit: kit.kit, width: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    kit.slot.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: widget.onDetails,
                  child: const Text('Match details'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: widget.onKits,
                  child: const Text('Kits'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// No match to show (TD3): the season isn't published yet, or every match
/// of this switch is played.
class NoMatchCard extends StatelessWidget {
  const NoMatchCard({super.key, required this.anyMatches});

  /// The club has matches (all played, or only in the other competition).
  final bool anyMatches;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          const AccentIcon(
            icon: Icons.event_busy_rounded,
            tone: AccentTone.grey,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anyMatches ? 'No match coming up' : 'No matches yet',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  anyMatches
                      ? 'Your next matches show here when the FA adds them.'
                      : 'The FA has not published the season. Your matches '
                            'show here when it does.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Coming up: the next 2 matches as short rows (day, opponent's crest,
/// "Kwanyako United (away)", competition, round, time, ground).
class ComingUpCard extends StatelessWidget {
  const ComingUpCard({
    super.key,
    required this.fixtures,
    required this.teamId,
    required this.onTap,
  });

  final List<Fixture> fixtures;
  final String teamId;
  final ValueChanged<Fixture> onTap;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < fixtures.length; i++) ...[
            if (i > 0) Divider(height: 1, color: dashboardBorder(context)),
            _UpRow(
              fixture: fixtures[i],
              teamId: teamId,
              onTap: () => onTap(fixtures[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpRow extends StatelessWidget {
  const _UpRow({
    required this.fixture,
    required this.teamId,
    required this.onTap,
  });

  final Fixture fixture;
  final String teamId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final k = f.kickoffAt;
    final opponent = f.opponentOf(teamId);
    final where = f.isHome(teamId) ? 'home' : 'away';
    final competition = f.ageGroup == null
        ? f.category.label
        : '${f.category.label} ${f.ageGroup!.label}';
    final detail = [
      competition,
      'Round ${f.round}',
      if (k != null && !f.isPostponed) formatTime(k),
      if (!f.isPostponed) f.venue,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Column(
                children: [
                  Text(
                    k == null
                        ? 'NEW'
                        : formatShortDate(k).substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  Text(
                    k == null ? 'TBC' : '${k.toLocal().day}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FixtureCrest(side: opponent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${opponent.name} ($where)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                      if (f.isPostponed) ...[
                        const SizedBox(width: 6),
                        const HomeChip('Postponed', tone: AccentTone.gold),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }
}

/// One "Needs you" row, in words.
class TeamNeedRow {
  const TeamNeedRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.detail,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final AccentTone tone;
  final String label;
  final String detail;
  final VoidCallback onTap;

  /// The gold number on the right (players sent back), if any.
  final int? count;
}

/// The team's "Needs you" card (TD1): only what the team must do.
class TeamNeedsCard extends StatelessWidget {
  const TeamNeedsCard({super.key, required this.rows});

  final List<TeamNeedRow> rows;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: dashboardBorder(context),
              ),
            Semantics(
              button: true,
              label: '${rows[i].label}. ${rows[i].detail}',
              excludeSemantics: true,
              child: InkWell(
                onTap: rows[i].onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      AccentIcon(icon: rows[i].icon, tone: rows[i].tone),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].label,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              rows[i].detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: muted),
                            ),
                          ],
                        ),
                      ),
                      if (rows[i].count case final n?) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 28),
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.ghanaGold,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            n > 99 ? '99+' : '$n',
                            style: const TextStyle(
                              color: Color(0xFF3A2C00),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      Icon(Icons.chevron_right_rounded, color: muted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "All caught up" for a team (TD2).
class TeamCaughtUpCard extends StatelessWidget {
  const TeamCaughtUpCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AccentTone.green.background(isDark),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 28,
              color: AccentTone.green.foreground(isDark),
            ),
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
                  'Nothing waits for you. New things show up here by '
                  'themselves.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
