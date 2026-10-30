import 'package:cloud_firestore/cloud_firestore.dart';

/// The kinds of notification. Must match the rules.
enum NotificationKind {
  // For a team (written by the FA)
  playersApproved,
  playersRejected,
  teamApproved,
  paymentConfirmed, // season fee (2.13c)
  paymentNotFound,
  feeReminder,
  // For the FA (written by teams, clubs, invited people)
  teamRequest,
  playersSubmitted,
  playersResubmitted,
  inviteAccepted,
  paymentSent; // a team added a payment (2.13c)

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
        NotificationKind.inviteAccepted =>
          people == 1 ? 'Invitation accepted' : '$people invitations accepted',
        NotificationKind.paymentConfirmed =>
          people == 1 ? 'Payment confirmed' : '$people payments confirmed',
        NotificationKind.paymentNotFound => 'Payment not found',
        NotificationKind.feeReminder => 'Season fee reminder',
        NotificationKind.paymentSent => people == 1
            ? 'Payment from $teamName'
            : '$people payments from $teamName',
      };

  String get body => switch (kind) {
        NotificationKind.playersApproved =>
          '$namesText. They can now be picked on team sheets.',
        NotificationKind.playersRejected =>
          '$namesText. Open Squad › Rejected to read the reasons and correct '
              'them.',
        NotificationKind.teamApproved =>
          'Welcome to the league. You can now add your Division players.',
        NotificationKind.teamRequest => people == 1
            ? 'Sent by the club. Open it in Teams to review.'
            : '$namesText. Open Teams to review them.',
        NotificationKind.playersSubmitted =>
          '$namesText. Waiting for your review in Players.',
        NotificationKind.playersResubmitted =>
          '$namesText. Waiting for your review in Players.',
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
