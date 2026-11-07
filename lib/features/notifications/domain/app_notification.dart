import 'package:cloud_firestore/cloud_firestore.dart';

/// The kinds of notification. Must match the rules.
enum NotificationKind {
  // For a team (written by the FA)
  playersApproved,
  playersRejected,
  juvenilePassed, // screening day (2.14c)
  juvenileNotEligible,
  juvenileToCorrect, // "needs correcting" at screening (2.14d)
  teamApproved,
  paymentConfirmed, // season fee (2.13c)
  paymentNotFound,
  feeReminder,
  changeApproved, // name, short name, logo or competition (2.10b)
  changeRefused,
  teamCorrected, // the FA corrected a mistake itself (2.11a)
  correctionAsked, // the FA asks the team to correct something (2.11b)
  correctionDone, // the FA checked the team's correction
  teamSuspended, // by the chairman (2.11c)
  suspensionLifted,
  // For the FA (written by teams, clubs, invited people)
  teamRequest,
  playersSubmitted,
  playersResubmitted,
  juvenileSubmitted, // new juvenile players, waiting for screening (2.14b)
  teamUpdated, // a team changed its kits, ground… directly (2.10a)
  changeRequested, // a team asks to change its name, logo… (2.10b)
  correctionSentBack, // a team corrected what the FA asked (2.11b)
  inviteAccepted,
  paymentSent, // a team added a payment (2.13c)
  registrationChanged; // an FA official opened or closed registration

  static NotificationKind? fromString(String? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// `notifications/{id}`: ONE document per audience, kind, team and day.
/// Each new event updates it (count + 1, one more name), so approving 20
/// players makes 1 notification, not 20.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.teamId,
    required this.teamName,
    required this.names,
    required this.count,
    this.updatedAt,
  });

  final String id;
  final NotificationKind kind;
  final String teamId;
  final String teamName;
  final List<String> names; // e.g. "Kojo Arthur (GE26-0011)"
  final int count;
  final DateTime? updatedAt;

  /// "Kojo Arthur, Nana Ofori and 2 more"
  String get namesText {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    if (names.length <= 3) {
      return '${names.sublist(0, names.length - 1).join(', ')} and '
          '${names.last}';
    }
    return '${names.take(2).join(', ')} and ${names.length - 2} more';
  }

  String _players(int n) => n == 1 ? '1 player' : '$n players';

  /// How many different players / clubs / people. Saving the same one
  /// twice adds 1 to `count` but not a second name, so the names decide.
  int get people => names.isEmpty ? count : names.length;

  String get title => switch (kind) {
        NotificationKind.playersApproved => '${_players(people)} approved',
        NotificationKind.playersRejected => '${_players(people)} rejected',
        NotificationKind.juvenilePassed => people == 1
            ? '1 juvenile player passed'
            : '$people juvenile players passed',
        NotificationKind.juvenileNotEligible => people == 1
            ? '1 child not eligible for Juvenile'
            : '$people children not eligible for Juvenile',
        NotificationKind.juvenileToCorrect => people == 1
            ? '1 juvenile player to correct'
            : '$people juvenile players to correct',
        NotificationKind.teamApproved => '$teamName approved',
        NotificationKind.teamRequest => people == 1
            ? 'New team request: ${names.firstOrNull ?? teamName}'
            : '$people new team requests',
        NotificationKind.playersSubmitted =>
          people == 1
              ? 'New player from $teamName'
              : '$people new players from $teamName',
        NotificationKind.playersResubmitted =>
          people == 1
              ? 'Player resubmitted ($teamName)'
              : '$people players resubmitted ($teamName)',
        NotificationKind.teamUpdated => '$teamName updated their profile',
        NotificationKind.juvenileSubmitted => people == 1
            ? 'New juvenile player from $teamName'
            : '$people juvenile players from $teamName',
        NotificationKind.inviteAccepted =>
          people == 1 ? 'Invitation accepted' : '$people invitations accepted',
        NotificationKind.paymentConfirmed =>
          people == 1 ? 'Payment confirmed' : '$people payments confirmed',
        NotificationKind.paymentNotFound => 'Payment not found',
        NotificationKind.feeReminder => 'Season fee reminder',
        NotificationKind.paymentSent => people == 1
            ? 'Payment from $teamName'
            : '$people payments from $teamName',
        NotificationKind.registrationChanged => 'Registration changed',
        NotificationKind.changeRequested => people == 1
            ? '$teamName asked for a change'
            : '$teamName asked for $people changes',
        NotificationKind.changeApproved =>
          people == 1 ? 'Change approved' : '$people changes approved',
        NotificationKind.changeRefused =>
          people == 1 ? 'Change not approved' : '$people changes not approved',
        NotificationKind.teamCorrected => people == 1
            ? 'The FA corrected your team profile'
            : '$people corrections by the FA',
        NotificationKind.correctionAsked => 'The FA asked for a correction',
        NotificationKind.correctionDone => 'The FA marked your correction done',
        NotificationKind.correctionSentBack =>
          '$teamName sent their correction back',
        NotificationKind.teamSuspended => '$teamName is suspended',
        NotificationKind.suspensionLifted => 'Suspension lifted',
      };

  String get body => switch (kind) {
        NotificationKind.playersApproved =>
          '$namesText. They can now be picked on team sheets.',
        NotificationKind.playersRejected =>
          '$namesText. Open Squad › Rejected to read the reasons and correct '
              'them.',
        NotificationKind.juvenilePassed =>
          '$namesText. Passed at screening, with their player IDs.',
        NotificationKind.juvenileNotEligible =>
          '$namesText. The reasons are on each player in Squad › Juvenile.',
        NotificationKind.juvenileToCorrect =>
          '$namesText. Open Squad › Juvenile to read what to fix, then send '
              'them again for screening.',
        NotificationKind.teamApproved =>
          'Welcome to the league. You can now add your Division players.',
        NotificationKind.teamRequest => people == 1
            ? 'Sent by the club. Open it in Teams to review.'
            : '$namesText. Open Teams to review them.',
        NotificationKind.playersSubmitted =>
          '$namesText. Waiting for your review in Players.',
        NotificationKind.playersResubmitted =>
          '$namesText. Waiting for your review in Players.',
        NotificationKind.juvenileSubmitted =>
          '$namesText. Waiting for the screening day; see Players › '
              'Juvenile.',
        NotificationKind.teamUpdated =>
          'Changed: $namesText. Saved straight away (no approval needed).',
        NotificationKind.inviteAccepted => '$namesText.',
        NotificationKind.paymentConfirmed =>
          '$namesText. See More › Season fee.',
        NotificationKind.paymentNotFound =>
          '$namesText. Check the details and send it again in More › '
              'Season fee.',
        // The latest balance the FA sent today
        NotificationKind.feeReminder =>
          '${names.lastOrNull ?? 'Part of the fee'} left to pay. Pay to '
              "GEDFA's MoMo and add the payment in More › Season fee.",
        NotificationKind.paymentSent =>
          '$namesText. Confirm it in More › Season fees.',
        NotificationKind.registrationChanged =>
          '$namesText. See More › League settings.',
        NotificationKind.changeRequested =>
          '$namesText. Open Teams › Changes to decide.',
        NotificationKind.changeApproved =>
          '$namesText. It is used everywhere from now on.',
        NotificationKind.changeRefused =>
          "$namesText. Open More › Team profile to read the FA's reason.",
        NotificationKind.teamCorrected =>
          '$namesText. See More › Team profile.',
        NotificationKind.correctionAsked =>
          "To correct: ${names.lastOrNull ?? ''}. Read the FA's message on "
              'your Squad tab.',
        NotificationKind.correctionDone =>
          '${names.lastOrNull ?? 'Your correction'}: all good.',
        NotificationKind.correctionSentBack =>
          '${names.lastOrNull ?? ''}. Check it in Teams › Changes.',
        NotificationKind.teamSuspended =>
          '"${names.lastOrNull ?? ''}" Contact the FA.',
        NotificationKind.suspensionLifted =>
          '${names.lastOrNull ?? ''}. You can add and edit players again.',
      };

  static AppNotification? fromMap(String id, Map<String, dynamic> data) {
    final kind = NotificationKind.fromString(data['kind'] as String?);
    if (kind == null) return null;
    return AppNotification(
      id: id,
      kind: kind,
      teamId: data['teamId'] as String? ?? '',
      teamName: data['teamName'] as String? ?? '',
      names: [
        for (final n in data['names'] as List<dynamic>? ?? const [])
          n.toString(),
      ],
      count: (data['count'] as num?)?.toInt() ?? 1,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
