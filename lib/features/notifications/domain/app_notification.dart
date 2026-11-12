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
  fixtureAdded, // matches (3.0a)
  fixtureChanged,
  fixturePostponed,
  fixtureCancelled,
  playerSuspended, // the FA suspends a player for matches (3.1e1)
  playerSuspensionLifted,
  // For one person: a referee or FA official (3.5a), written by the FA
  appointed,
  appointmentRemoved,
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
  divisionJuveniles, // a club named or removed juveniles for the Division (3.1d)
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
    this.audience = '',
    required this.kind,
    required this.teamId,
    required this.teamName,
    required this.names,
    required this.count,
    this.updatedAt,
    this.targetId,
  });

  final String id;
  final String audience; // 'fa' or 'team:<teamId>'
  final NotificationKind kind;
  final String teamId;
  final String teamName;
  final List<String> names; // e.g. "Kojo Arthur (GE26-0011)"
  final int count;
  final DateTime? updatedAt;

  /// The thing the note is about, when it has one (3.1e1: the player).
  /// A grouped note keeps the latest one.
  final String? targetId;

  /// Player suspension notes (3.1e1) store each name as
  /// "headline — details": "Kofi Boateng suspended for 2 matches — Red
  /// card. Misses …". Splits it in two (no " — ": all headline).
  static (String, String) splitLine(String line) {
    final at = line.indexOf(lineBreak);
    return at < 0
        ? (line, '')
        : (line.substring(0, at), line.substring(at + lineBreak.length));
  }

  /// Between a suspension note's headline and its details.
  static const lineBreak = ' — ';

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
        NotificationKind.divisionJuveniles =>
          '$teamName: juveniles in the Division',
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
        NotificationKind.fixtureAdded =>
          people == 1 ? 'New match' : '$people new matches',
        NotificationKind.fixtureChanged =>
          people == 1 ? 'Match changed' : '$people matches changed',
        NotificationKind.fixturePostponed =>
          people == 1 ? 'Match postponed' : '$people matches postponed',
        NotificationKind.fixtureCancelled =>
          people == 1 ? 'Match cancelled' : '$people matches cancelled',
        NotificationKind.playerSuspended => people == 1
            ? splitLine(names.firstOrNull ?? 'A player suspended').$1
            : '$people players suspended',
        NotificationKind.playerSuspensionLifted => people == 1
            ? 'Suspension lifted: '
                '${splitLine(names.firstOrNull ?? 'a player').$1}'
            : '$people suspensions lifted',
        // "You are the referee"
        NotificationKind.appointed => people == 1
            ? splitLine(names.firstOrNull ?? 'You are appointed').$1
            : '$people new appointments',
        NotificationKind.appointmentRemoved => people == 1
            ? 'Appointment taken off'
            : '$people appointments taken off',
      };

  /// The short text in the bell's list ("Kojo Arthur, Nana Ofori and 2
  /// more. They can now be picked…").
  String get body => _text(namesText);

  /// The details page (3.0f): the text without the names when they are
  /// listed one per line under it ([listsNames]), else the whole text.
  String get detailText => _text(listsNames ? null : namesText);

  /// Whether the names are a list of players / clubs / changes that the
  /// details page shows in full, one per line.
  bool get listsNames {
    if (names.isEmpty) return false;
    return switch (kind) {
      NotificationKind.teamRequest => people > 1,
      NotificationKind.teamApproved ||
      NotificationKind.feeReminder ||
      NotificationKind.correctionAsked ||
      NotificationKind.correctionDone ||
      NotificationKind.correctionSentBack ||
      NotificationKind.teamSuspended ||
      NotificationKind.suspensionLifted => false,
      // One player: the details are the text; several: one line each
      NotificationKind.playerSuspended ||
      NotificationKind.playerSuspensionLifted ||
      NotificationKind.appointed ||
      NotificationKind.appointmentRemoved => people > 1,
      _ => true,
    };
  }

  /// "From GEDFA" on a team's or a person's notes; on the FA's, the team
  /// that did it.
  String get sender {
    if (audience != 'fa') return 'GEDFA';
    return switch (kind) {
      NotificationKind.teamRequest when people > 1 => '$people clubs',
      NotificationKind.inviteAccepted ||
      NotificationKind.registrationChanged => 'GEDFA',
      _ => teamName.isEmpty ? 'GEDFA' : teamName,
    };
  }

  /// [names] null: leave the names out (the details page lists them).
  String _text(String? names) {
    String withNames(String rest) => names == null
        ? rest
        : rest.isEmpty
            ? '$names.'
            : '$names. $rest';
    return switch (kind) {
      NotificationKind.playersApproved =>
        withNames('They can now be picked on team sheets.'),
      NotificationKind.playersRejected => withNames(
          'Open Squad › Rejected to read the reasons and correct them.'),
      NotificationKind.juvenilePassed =>
        withNames('Passed at screening, with their player IDs.'),
      NotificationKind.juvenileNotEligible => withNames(
          'The reasons are on each player in Squad › Juvenile.'),
      NotificationKind.juvenileToCorrect => withNames(
          'Open Squad › Juvenile to read what to fix, then send them again '
          'for screening.'),
      NotificationKind.teamApproved =>
        'Welcome to the league. You can now add your Division players.',
      NotificationKind.teamRequest => people == 1
          ? 'Sent by the club. Open it in Teams to review.'
          : withNames('Open Teams to review them.'),
      NotificationKind.playersSubmitted =>
        withNames('Waiting for your review in Players.'),
      NotificationKind.playersResubmitted =>
        withNames('Waiting for your review in Players.'),
      NotificationKind.juvenileSubmitted => withNames(
          'Waiting for the screening day; see Players › Juvenile.'),
      NotificationKind.divisionJuveniles => withNames(
          'Named (+) or removed (−) by the club; up to 7 may play Division '
          'matches. No approval needed.'),
      NotificationKind.teamUpdated => names == null
          ? 'Saved straight away (no approval needed). Changed:'
          : 'Changed: $names. Saved straight away (no approval needed).',
      NotificationKind.inviteAccepted => withNames(''),
      NotificationKind.paymentConfirmed =>
        withNames('See More › Season fee.'),
      NotificationKind.paymentNotFound => withNames(
          'Check the details and send it again in More › Season fee.'),
      // The latest balance the FA sent today
      NotificationKind.feeReminder =>
        '${this.names.lastOrNull ?? 'Part of the fee'} left to pay. Pay to '
            "GEDFA's MoMo and add the payment in More › Season fee.",
      NotificationKind.paymentSent =>
        withNames('Confirm it in More › Season fees.'),
      NotificationKind.registrationChanged =>
        withNames('See More › League settings.'),
      NotificationKind.changeRequested =>
        withNames('Open Teams › Changes to decide.'),
      NotificationKind.changeApproved =>
        withNames('It is used everywhere from now on.'),
      NotificationKind.changeRefused =>
        withNames("Open More › Team profile to read the FA's reason."),
      NotificationKind.teamCorrected =>
        withNames('See More › Team profile.'),
      NotificationKind.correctionAsked =>
        "To correct: ${this.names.lastOrNull ?? ''}. Read the FA's message "
            'on your Squad tab.',
      NotificationKind.correctionDone =>
        '${this.names.lastOrNull ?? 'Your correction'}: all good.',
      NotificationKind.correctionSentBack =>
        '${this.names.lastOrNull ?? ''}. Check it in Teams › Changes.',
      NotificationKind.teamSuspended =>
        '"${this.names.lastOrNull ?? ''}" Contact the FA.',
      NotificationKind.suspensionLifted =>
        '${this.names.lastOrNull ?? ''}. You can add and edit players again.',
      NotificationKind.fixtureAdded => withNames('See Fixtures.'),
      NotificationKind.fixtureChanged => withNames('See Fixtures.'),
      NotificationKind.fixturePostponed => withNames('See Fixtures.'),
      NotificationKind.fixtureCancelled => withNames('See Fixtures.'),
      NotificationKind.playerSuspended ||
      NotificationKind.playerSuspensionLifted => people == 1
          ? splitLine(this.names.firstOrNull ?? '').$2
          : names == null
              ? 'Open Squad to see when each one returns.'
              : '$names. Open Squad to see when each one returns.',
      NotificationKind.appointed => people == 1
          ? splitLine(this.names.firstOrNull ?? '').$2
          : withNames('See your matches.'),
      NotificationKind.appointmentRemoved => people == 1
          ? '${splitLine(this.names.firstOrNull ?? '').$2} The FA took you '
                'off this match.'
          : withNames('The FA took you off these matches.'),
    };
  }

  static AppNotification? fromMap(String id, Map<String, dynamic> data) {
    final kind = NotificationKind.fromString(data['kind'] as String?);
    if (kind == null) return null;
    return AppNotification(
      id: id,
      audience: data['audience'] as String? ?? '',
      kind: kind,
      teamId: data['teamId'] as String? ?? '',
      teamName: data['teamName'] as String? ?? '',
      names: [
        for (final n in data['names'] as List<dynamic>? ?? const [])
          n.toString(),
      ],
      count: (data['count'] as num?)?.toInt() ?? 1,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      targetId: data['targetId'] as String?,
    );
  }
}
