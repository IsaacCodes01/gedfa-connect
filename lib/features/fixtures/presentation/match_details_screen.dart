import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/open_link.dart';
import 'package:gedfa_connect/core/widgets/flag_stripe.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_actions.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_thumb.dart';

/// Match details (mockups F5 coming up, F6 played): a stadium-night header
/// with both crests, the kick-off and a countdown; then the match info
/// (date, time, ground with directions, competition, match length, team
/// sheets due), what changed, the kits each side wears, team sheets and
/// officials. The FA ([isFa]) can also manage the match from here.
class MatchDetailsScreen extends ConsumerWidget {
  const MatchDetailsScreen({
    super.key,
    required this.fixtureId,
    this.isFa = false,
  });

  final String fixtureId;
  final bool isFa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixtureAsync = ref.watch(fixtureProvider(fixtureId));
    return fixtureAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
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
          : _Details(fixture: f, isFa: isFa),
    );
  }
}

class _Details extends ConsumerStatefulWidget {
  const _Details({required this.fixture, required this.isFa});

  final Fixture fixture;
  final bool isFa;

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  // The countdown moves on every minute
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    final now = DateTime.now();
    final history =
        ref.watch(fixtureHistoryProvider(f.id)).value ?? const [];
    // "Match added" alone is not news
    final changes = [
      for (final c in history)
        if (c.what != 'Match added') c,
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Hero(fixture: f, now: now, isFa: widget.isFa),
            const FlagStripe(height: 4),
            ResponsiveCenter(
              maxWidth: 720,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DashboardSectionTitle(title: 'Match info'),
                    _Info(fixture: f, now: now),
                    if (changes.isNotEmpty) ...[
                      const DashboardSectionTitle(title: 'What changed'),
                      _Changes(changes: changes),
                    ],
                    DashboardSectionTitle(
                      title: f.isPlayed(now) ? 'What they wore' : 'What they wear',
                      trailing: "From each team's kits",
                    ),
                    _Kits(fixture: f),
                    DashboardSectionTitle(
                      title: 'Team sheets',
                      trailing: f.sheetDueAt == null
                          ? null
                          : 'Due ${formatShortDate(f.sheetDueAt!)}, '
                              '${formatTime(f.sheetDueAt!)}',
                    ),
                    _Sheets(fixture: f, now: now),
                    const DashboardSectionTitle(
                      title: 'Officials',
                      trailing: 'Phase 4',
                    ),
                    const _Line(
                      icon: Icons.sports_outlined,
                      title: 'Referee and assistants',
                      detail: 'Appointed by the FA (comes with referee '
                          'appointments)',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- The header ----------

class _Hero extends StatelessWidget {
  const _Hero({required this.fixture, required this.now, required this.isFa});

  final Fixture fixture;
  final DateTime now;
  final bool isFa;

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final played = f.isPlayed(now);
    final kickoff = f.kickoffAt;
    final top = MediaQuery.paddingOf(context).top;
    const white = TextStyle(color: Colors.white);
    final soft = Colors.white.withValues(alpha: 0.85);

    // "DIVISION · MATCHDAY 4" or "JUVENILE U15 · MATCHDAY 2"
    final competition = '${f.ageGroup == null ? 'DIVISION' : 'JUVENILE '
        '${f.ageGroup!.label}'} · MATCHDAY ${f.round}';

    // Middle: the time, the score to come, or why there's none
    final Widget middle;
    if (f.isCancelled) {
      middle = const _Middle(big: '✕', small: 'CANCELLED');
    } else if (f.isPostponed || kickoff == null) {
      middle = const _Middle(big: 'TBC', small: 'POSTPONED');
    } else if (played) {
      middle = _Middle(
        big: '– : –',
        small: 'PLAYED · ${formatShortDate(kickoff).toUpperCase()}',
      );
    } else {
      final t = formatTime(kickoff).split(' ');
      middle = _Middle(
        big: t.first,
        small: '${t.last.toUpperCase()} · '
            '${formatShortDate(kickoff).toUpperCase()}',
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.3,
          colors: played || !f.isScheduled
              ? const [Color(0xFF3A5C7E), Color(0xFF1B3350), Color(0xFF081A30)]
              : const [Color(0xFF2E7BD6), Color(0xFF12407A), Color(0xFF081A30)],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: [
          // Pitch lines and a gold floodlight glow, only for looks
          const Positioned.fill(
            child: Opacity(
              opacity: 0.13,
              child: CustomPaint(painter: _PitchPainter()),
            ),
          ),
          if (!played && f.isScheduled)
            Positioned(
              top: -130,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.ghanaGold.withValues(alpha: 0.35),
                        AppColors.ghanaGold.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, top + 8, 8, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Match details',
                        style: white.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isFa)
                      Consumer(
                        builder: (context, ref, _) => IconButton(
                          onPressed: () =>
                              showFixtureActions(context, ref, f),
                          tooltip: 'Manage this match',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.14),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  competition,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: soft,
                    fontSize: 11.5,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _BigTeam(side: f.home, label: 'HOME')),
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: middle,
                      ),
                      Expanded(child: _BigTeam(side: f.away, label: 'AWAY')),
                    ],
                  ),
                ),
                if (f.isScheduled && !played && kickoff != null) ...[
                  const SizedBox(height: 16),
                  _Countdown(left: kickoff.difference(now)),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stadium_outlined, size: 18, color: soft),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        f.venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: soft, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                if (played) ...[
                  const SizedBox(height: 4),
                  Text(
                    "The score, scorers and cards come with the referee's "
                    'report (Phase 4)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Middle extends StatelessWidget {
  const _Middle({required this.big, required this.small});

  final String big;
  final String small;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          big,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          small,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _BigTeam extends StatelessWidget {
  const _BigTeam({required this.side, required this.label});

  final FixtureSide side;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: FixtureCrest(side: side, size: 72),
        ),
        const SizedBox(height: 8),
        Text(
          side.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 10.5,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.left});

  final Duration left;

  @override
  Widget build(BuildContext context) {
    final l = left.isNegative ? Duration.zero : left;
    Widget box(String value, String label) => Container(
          constraints: const BoxConstraints(minWidth: 58),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
    return Semantics(
      label: 'Kick-off in ${l.inDays} days, ${l.inHours % 24} hours, '
          '${l.inMinutes % 60} minutes',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          box('${l.inDays}', 'DAYS'),
          const SizedBox(width: 8),
          box('${l.inHours % 24}', 'HRS'),
          const SizedBox(width: 8),
          box('${l.inMinutes % 60}', 'MIN'),
        ],
      ),
    );
  }
}

/// A football pitch in thin lines (the header background).
class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final w = size.width, h = size.height;
    final pitch = Rect.fromLTRB(w * 0.06, h * 0.04, w * 0.94, h * 0.96);
    canvas.drawRect(pitch, p);
    canvas.drawLine(Offset(pitch.left, h / 2), Offset(pitch.right, h / 2), p);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.13, p);
    final boxW = w * 0.44, boxH = h * 0.14;
    canvas.drawRect(
      Rect.fromLTWH((w - boxW) / 2, pitch.top, boxW, boxH),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH((w - boxW) / 2, pitch.bottom - boxH, boxW, boxH),
      p,
    );
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}

// ---------- The body ----------

class _Info extends StatelessWidget {
  const _Info({required this.fixture, required this.now});

  final Fixture fixture;
  final DateTime now;

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final k = f.kickoffAt;
    final due = f.sheetDueAt;
    final group = f.ageGroup;

    final status = switch (f.status) {
      FixtureStatus.cancelled => 'Cancelled',
      FixtureStatus.postponed => 'Postponed, new date to come',
      FixtureStatus.scheduled when f.isPlayed(now) => 'Played',
      FixtureStatus.scheduled => 'Scheduled',
    };

    return DashboardCard(
      child: Column(
        children: [
          _Line(
            icon: Icons.calendar_today_outlined,
            title: k == null
                ? 'Date to come'
                : '${_weekdays[k.toLocal().weekday - 1]}, '
                    '${formatShortDate(k).substring(4)} ${k.toLocal().year}',
            detail: k == null ? 'The FA sets the new date' : 'Date',
          ),
          if (k != null)
            _Line(
              icon: Icons.schedule_outlined,
              title: formatTime(k),
              detail: 'Kick-off',
            ),
          _Line(
            icon: Icons.location_on_outlined,
            title: f.venue,
            detail: '${f.home.name} is the home team',
            trailing: TextButton.icon(
              onPressed: () => openLink(
                'https://www.google.com/maps/search/?api=1&query='
                '${Uri.encodeComponent('${f.venue}, Gomoa East, Ghana')}',
              ),
              icon: const Icon(Icons.directions_outlined, size: 18),
              label: const Text('Directions'),
            ),
          ),
          _Line(
            icon: Icons.emoji_events_outlined,
            title: '${f.category.label} League'
                '${group == null ? '' : ' ${group.label}'} · Matchday ${f.round}',
            detail: 'Competition',
          ),
          _Line(
            icon: Icons.timer_outlined,
            title: group?.matchLengthText ?? '2 × 45 min',
            detail: group?.playUpText ?? 'Match length',
          ),
          if (due != null && f.isScheduled)
            _Line(
              icon: Icons.assignment_outlined,
              title: '${formatShortDate(due)}, ${formatTime(due)}',
              detail: 'Team sheets due (1 hour before kick-off)',
            ),
          _Line(
            icon: f.isScheduled
                ? Icons.check_circle_outline
                : Icons.error_outline,
            title: status,
            detail: (f.note ?? '').isNotEmpty && !f.isScheduled
                ? 'Reason: ${f.note}'
                : 'Status',
          ),
        ],
      ),
    );
  }
}

class _Changes extends StatelessWidget {
  const _Changes({required this.changes});

  final List<FixtureChange> changes;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        children: [
          for (final c in changes.take(5))
            _Line(
              icon: Icons.history,
              title: c.what,
              detail: [
                if (c.at != null) formatDayMonthTime(c.at!),
                if ((c.reason ?? '').isNotEmpty) 'Why: ${c.reason}',
              ].join(' · '),
            ),
        ],
      ),
    );
  }
}

class _Kits extends StatelessWidget {
  const _Kits({required this.fixture});

  final Fixture fixture;

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    Widget side(FixtureSide team, KitChoice outfield, KitChoice gk) =>
        Expanded(
          child: DashboardCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    KitThumb(
                      kit: outfield.kit,
                      height: 84,
                      semanticLabel: '${team.name} ${outfield.slot.label}',
                    ),
                    const SizedBox(width: 8),
                    KitThumb(
                      kit: gk.kit,
                      height: 52,
                      semanticLabel: '${team.name} ${gk.slot.label}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  team.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  outfield.slot.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Goalkeeper: ${gk.slot.label.toLowerCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        side(f.home, f.kits.home, f.kits.homeGk),
        const SizedBox(width: 10),
        side(f.away, f.kits.away, f.kits.awayGk),
      ],
    );
  }
}

class _Sheets extends StatelessWidget {
  const _Sheets({required this.fixture, required this.now});

  final Fixture fixture;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final due = f.sheetDueAt;
    final open = due != null && f.isScheduled && due.isAfter(now);
    final left = due?.difference(now);
    final when = left == null
        ? ''
        : left.inDays >= 1
            ? 'Due in ${left.inDays} d'
            : 'Due in ${left.inHours} h ${left.inMinutes % 60} min';
    Widget row(FixtureSide side) => _Line(
          leading: FixtureCrest(side: side),
          title: side.name,
          detail: 'Team sheets come in the next update (3.1)',
          trailing: open
              ? FixtureTag(when, tone: AccentTone.gold)
              : null,
        );
    return DashboardCard(
      child: Column(children: [row(f.home), row(f.away)]),
    );
  }
}

/// One row: an icon (or [leading]), a title, a grey line, an optional
/// button or tag on the right.
class _Line extends StatelessWidget {
  const _Line({
    this.icon,
    this.leading,
    required this.title,
    required this.detail,
    this.trailing,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          leading ?? Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // A button or tag shrinks a little with very large text
          if (trailing case final t?)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: FittedBox(fit: BoxFit.scaleDown, child: t),
            ),
        ],
      ),
    );
  }
}
