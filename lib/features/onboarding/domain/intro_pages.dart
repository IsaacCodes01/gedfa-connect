import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';

/// One of the little white cards floating on the pitch (a picture only, not
/// real data). [top] / [bottom] are fractions of the picture's height;
/// [left] / [right] are pixels from the side.
class IntroChip {
  const IntroChip(
    this.icon,
    this.label,
    this.tone, {
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  final IconData icon;
  final String label;
  final AccentTone tone;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
}

/// One intro screen (I1–I3 in `refresh-light.html`).
class IntroPage {
  const IntroPage({
    required this.icon,
    required this.kicker,
    required this.title,
    required this.text,
    required this.chips,
  });

  final IconData icon;
  final String kicker;
  final String title;
  final String text;
  final List<IntroChip> chips;
}

/// Isaac's words, as approved in the mockup (12 Nov 2026).
const introPages = [
  IntroPage(
    icon: Icons.shield_rounded,
    kicker: 'Your club',
    title: 'Register your team and players in one place',
    text:
        'Send your team, players and officials to GEDFA from your phone. '
        'See what is approved, what is waiting, and your fee.',
    chips: [
      IntroChip(
        Icons.verified_rounded,
        'Team approved',
        AccentTone.green,
        top: 0.175,
        left: 22,
      ),
      IntroChip(
        Icons.badge_rounded,
        '18 players',
        AccentTone.blue,
        bottom: 0.115,
        right: 20,
      ),
      IntroChip(
        Icons.payments_rounded,
        'Fee paid',
        AccentTone.gold,
        bottom: 0.24,
        left: 30,
      ),
    ],
  ),
  IntroPage(
    icon: Icons.stadium_rounded,
    kicker: 'Match day',
    title: 'Fixtures, team sheets and officials, sorted',
    text:
        'See your matches, pick your 18 before the lock, and print the '
        'official sheet. Referees see their appointments and check the '
        'players.',
    chips: [
      IntroChip(
        Icons.event_rounded,
        'Sat 3:30 pm',
        AccentTone.blue,
        top: 0.165,
        right: 22,
      ),
      IntroChip(
        Icons.checklist_rounded,
        'Team sheet ready',
        AccentTone.green,
        bottom: 0.25,
        left: 20,
      ),
      IntroChip(
        Icons.sports_rounded,
        'Referee appointed',
        AccentTone.grey,
        bottom: 0.11,
        right: 28,
      ),
    ],
  ),
  IntroPage(
    icon: Icons.notifications_active_rounded,
    kicker: 'Stay in the game',
    title: 'Hear from GEDFA the moment it happens',
    text:
        'Approvals, fixtures, appointments, suspensions and news from the '
        'FA, all in your bell. Gomoa East football, connected.',
    chips: [
      IntroChip(
        Icons.campaign_rounded,
        'From GEDFA',
        AccentTone.blue,
        top: 0.16,
        left: 20,
      ),
      IntroChip(
        Icons.gavel_rounded,
        'Suspension lifted',
        AccentTone.red,
        bottom: 0.245,
        right: 18,
      ),
      IntroChip(
        Icons.emoji_events_rounded,
        'Cup draw',
        AccentTone.gold,
        bottom: 0.105,
        left: 34,
      ),
    ],
  ),
];
