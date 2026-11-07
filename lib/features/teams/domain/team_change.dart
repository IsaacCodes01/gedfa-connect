import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// What a team can ask the FA to change (2.10b). Everything else on the
/// team profile saves straight away (2.10a).
enum TeamChangeKind {
  name('Club name', 'Name change', 'name'),
  shortName('Short name', 'Short name change', 'short name'),
  logo('Logo', 'New logo', 'logo'),
  competition('Add a competition', 'Add a competition', 'competition');

  const TeamChangeKind(this.chip, this.title, this.noun);

  /// The chip on "Ask the FA to change"
  final String chip;

  /// The FA's review screen title
  final String title;

  /// In sentences: "Royal Unique FC asked for a new short name"
  final String noun;

  static TeamChangeKind? fromString(String? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// `teamChanges/{teamId}_{kind}`: a team's request to the FA. One per
/// team and kind, so there is only ever one pending request of each
/// kind; asking again after the FA decided replaces the old one.
///
/// Until the FA approves, the old details are used everywhere.
class TeamChange {
  const TeamChange({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.kind,
    required this.to,
    required this.reason,
    required this.status,
    this.from,
    this.fromCompetitions = const {},
    this.nameKey,
    this.askedByName,
    this.rejectionReason,
    this.createdAt,
    this.reviewedAt,
  });

  final String id;
  final String teamId;

  /// The team's name when it asked (the old name, for a name change)
  final String teamName;
  final TeamChangeKind kind;

  /// The value now: old name, short name or logo link
  final String? from;

  /// [TeamChangeKind.competition]: the competitions the club plays now
  final Set<Competition> fromCompetitions;

  /// The new value: name, short name, logo link, or the competition to
  /// add ('division' / 'juvenile')
  final String to;

  /// The new name's reservation key (name changes only)
  final String? nameKey;

  /// "Why? (for the FA)"
  final String reason;
  final ApprovalStatus status;
  final String? askedByName;

  /// Why the FA did not approve
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  static String idFor(String teamId, TeamChangeKind kind) =>
      '${teamId}_${kind.name}';

  bool get isPending => status == ApprovalStatus.pending;

  /// The competition to add (competition requests)
  Competition? get competition => Competition.fromString(to);

  /// "Name → Golden Unity Stars FC", "New logo", "Add Juvenile"…, the
  /// short line in lists and on the team page.
  String get summary => switch (kind) {
        TeamChangeKind.name => 'Name → $to',
        TeamChangeKind.shortName => 'Short name → $to',
        TeamChangeKind.logo => 'New logo',
        TeamChangeKind.competition => 'Add ${competition?.label ?? to}',
      };

  /// "name → Gomoa Super Eagles", "short name FR → FRFC": the FA's
  /// Decided list
  String get decidedText => switch (kind) {
        TeamChangeKind.name => 'name → $to',
        TeamChangeKind.shortName => 'short name ${from ?? ''} → $to',
        TeamChangeKind.logo => 'new logo',
        TeamChangeKind.competition =>
          'add ${competition?.label ?? to}',
      };

  factory TeamChange.fromMap(String id, Map<String, dynamic> data) {
    final from = data['from'];
    return TeamChange(
      id: id,
      teamId: data['teamId'] as String? ?? '',
      teamName: data['teamName'] as String? ?? '',
      kind: TeamChangeKind.fromString(data['kind'] as String?) ??
          TeamChangeKind.name,
      from: from is String ? from : null,
      fromCompetitions: from is List
          ? Competition.fromList(from)
          : const <Competition>{},
      to: data['to'] as String? ?? '',
      nameKey: data['nameKey'] as String?,
      reason: data['reason'] as String? ?? '',
      status: ApprovalStatus.fromString(data['status'] as String? ?? ''),
      askedByName: data['askedByName'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }
}
