import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';

/// The colour of a note's round icon: good news, bad news, from the FA,
/// from a team, from a person (referee, official).
enum NoteLook { ok, no, fa, team, ref }

/// The icon and its two colours for [look], in light and dark.
(IconData, Color, Color) noteIcon(BuildContext context, NoteLook look) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (look) {
    NoteLook.ok => (
        Icons.check_rounded,
        isDark ? const Color(0xFF123D2B) : AppColors.approvedBg,
        isDark ? const Color(0xFF7BE3B0) : AppColors.approvedText,
      ),
    NoteLook.no => (
        Icons.close_rounded,
        isDark ? const Color(0xFF4A1820) : AppColors.rejectedBg,
        isDark ? const Color(0xFFFF9DA6) : AppColors.rejectedText,
      ),
    NoteLook.fa => (
        Icons.campaign_outlined,
        isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA),
        isDark ? const Color(0xFF9CCBFA) : AppColors.deepBlue,
      ),
    NoteLook.team => (
        Icons.shield_outlined,
        isDark ? const Color(0xFF3D3410) : AppColors.pendingBg,
        isDark ? const Color(0xFFF5D25B) : AppColors.pendingText,
      ),
    NoteLook.ref => (
        Icons.how_to_reg_outlined,
        isDark ? const Color(0xFF2A2147) : const Color(0xFFEEE8FF),
        isDark ? const Color(0xFFC9B8FF) : const Color(0xFF4B2E9E),
      ),
  };
}

/// How a note looks, where its details button goes, and the button's
/// name ("Open Squad", "Review players"…). [requestUid] is the club account
/// of the note's team (the FA's team page), when known.
({NoteLook look, String target, String button}) noteTarget(
  AppNotification n, {
  String? requestUid,
}) {
  const squad = 'Open Squad';
  const fee = 'Open Season fee';
  const fixtures = 'Open Fixtures';
  const profile = 'Open Team profile';
  const changes = 'Open Changes';
  final (look, target, button) = switch (n.kind) {
    NotificationKind.playersApproved => (NoteLook.ok, Routes.team, squad),
    NotificationKind.playersRejected => (NoteLook.no, Routes.team, squad),
    NotificationKind.juvenilePassed => (NoteLook.ok, Routes.team, squad),
    NotificationKind.juvenileNotEligible => (NoteLook.no, Routes.team, squad),
    NotificationKind.juvenileToCorrect => (NoteLook.no, Routes.team, squad),
    NotificationKind.teamApproved => (NoteLook.team, Routes.team, squad),
    // One club: its request. Several (grouped): the list of requests.
    NotificationKind.teamRequest => n.people == 1
        ? (NoteLook.team, Routes.adminRequest(n.teamId), 'Open the request')
        : (NoteLook.team, Routes.admin, 'Open Teams'),
    NotificationKind.playersSubmitted =>
      (NoteLook.ok, Routes.adminTeamPlayers(n.teamId), 'Review players'),
    NotificationKind.playersResubmitted =>
      (NoteLook.no, Routes.adminTeamPlayers(n.teamId), 'Review players'),
    // The FA's team page (2.11b), found by the club's account
    NotificationKind.teamUpdated => switch (requestUid) {
        final uid? => (NoteLook.fa, Routes.adminRequest(uid), 'Open the team'),
        null => (
            NoteLook.fa,
            Routes.adminTeamPlayers(n.teamId),
            'Open the team',
          ),
      },
    // Players › Juvenile › that team's children
    NotificationKind.juvenileSubmitted =>
      (NoteLook.fa, Routes.adminTeamJuvenile(n.teamId), 'Open Juvenile'),
    NotificationKind.divisionJuveniles =>
      (NoteLook.team, Routes.adminTeamPlayers(n.teamId), 'Open the squad'),
    NotificationKind.inviteAccepted =>
      (NoteLook.ref, Routes.adminPeople, 'Open People'),
    NotificationKind.paymentConfirmed => (NoteLook.ok, Routes.teamFee, fee),
    NotificationKind.paymentNotFound => (NoteLook.no, Routes.teamFee, fee),
    NotificationKind.feeReminder => (NoteLook.fa, Routes.teamFee, fee),
    NotificationKind.paymentSent =>
      (NoteLook.team, Routes.adminTeamFee(n.teamId), 'Open the payment'),
    NotificationKind.registrationChanged =>
      (NoteLook.fa, Routes.adminLeagueSettings, 'Open League settings'),
    // Change requests (2.10b): Teams › Changes, and the team's page
    NotificationKind.changeRequested =>
      (NoteLook.team, Routes.adminChanges, changes),
    NotificationKind.changeApproved => (NoteLook.ok, Routes.teamClub, profile),
    NotificationKind.changeRefused => (NoteLook.no, Routes.teamClub, profile),
    NotificationKind.teamCorrected => (NoteLook.fa, Routes.teamClub, profile),
    // Ask the team to correct (2.11b): the banner on the Squad tab
    NotificationKind.correctionAsked => (NoteLook.no, Routes.team, squad),
    NotificationKind.correctionDone => (NoteLook.ok, Routes.team, squad),
    NotificationKind.correctionSentBack =>
      (NoteLook.team, Routes.adminChanges, changes),
    // Suspensions (2.11c): the red banner on the Squad tab
    NotificationKind.teamSuspended => (NoteLook.no, Routes.team, squad),
    NotificationKind.suspensionLifted => (NoteLook.ok, Routes.team, squad),
    NotificationKind.fixtureAdded => (NoteLook.fa, Routes.teamFixtures, fixtures),
    NotificationKind.fixtureChanged =>
      (NoteLook.fa, Routes.teamFixtures, fixtures),
    NotificationKind.fixturePostponed =>
      (NoteLook.no, Routes.teamFixtures, fixtures),
    NotificationKind.fixtureCancelled =>
      (NoteLook.no, Routes.teamFixtures, fixtures),
    // Player suspensions (3.1e1, SP5): one player opens their page
    NotificationKind.playerSuspended => switch (n.targetId) {
        final id? when n.people == 1 =>
          (NoteLook.no, Routes.player(id), 'Open the player'),
        _ => (NoteLook.no, Routes.team, squad),
      },
    NotificationKind.playerSuspensionLifted => switch (n.targetId) {
        final id? when n.people == 1 =>
          (NoteLook.ok, Routes.player(id), 'Open the player'),
        _ => (NoteLook.ok, Routes.team, squad),
      },
  };
  return (look: look, target: target, button: button);
}
