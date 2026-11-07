import 'package:cloud_firestore/cloud_firestore.dart';

/// What the FA can ask a team to correct (2.11b, mockup B2).
enum CorrectionItem {
  clubDetails('Club details'),
  officials('Officials'),
  kits('Colours and kits'),
  players('Players (photos, names, dates of birth)');

  const CorrectionItem(this.label);

  final String label;

  /// "Players", without the hint in brackets (for the banner)
  String get shortLabel => switch (this) {
        CorrectionItem.players => 'Players',
        _ => label,
      };

  static Set<CorrectionItem> fromList(List<dynamic>? values) => {
        for (final item in CorrectionItem.values)
          if (values?.contains(item.name) ?? false) item,
      };
}

/// asked (the team is on it) → sentBack (the FA checks) → done.
enum CorrectionStatus {
  asked,
  sentBack,
  done;

  static CorrectionStatus fromString(String? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return CorrectionStatus.done;
  }
}

/// `correctionRequests/{teamId}`: what the FA asked a team to correct.
/// One per team; asking again replaces it (`round` + 1).
class CorrectionRequest {
  const CorrectionRequest({
    required this.teamId,
    required this.teamName,
    required this.items,
    required this.message,
    required this.status,
    required this.round,
    this.askedByName,
    this.askedAt,
    this.sentBackAt,
    this.doneAt,
  });

  final String teamId;
  final String teamName;
  final Set<CorrectionItem> items;
  final String message;
  final CorrectionStatus status;

  /// 1 the first time, 2 after "Ask again"…
  final int round;
  final String? askedByName;
  final DateTime? askedAt;
  final DateTime? sentBackAt;
  final DateTime? doneAt;

  bool get isOpen => status != CorrectionStatus.done;

  /// "Officials, Players"
  String get itemsText => [
        for (final item in CorrectionItem.values)
          if (items.contains(item)) item.shortLabel,
      ].join(', ');

  factory CorrectionRequest.fromMap(String teamId, Map<String, dynamic> data) {
    DateTime? time(String field) => (data[field] as Timestamp?)?.toDate();
    return CorrectionRequest(
      teamId: teamId,
      teamName: data['teamName'] as String? ?? '',
      items: CorrectionItem.fromList(data['items'] as List<dynamic>?),
      message: data['message'] as String? ?? '',
      status: CorrectionStatus.fromString(data['status'] as String?),
      round: (data['round'] as num?)?.toInt() ?? 1,
      askedByName: data['askedByName'] as String?,
      askedAt: time('askedAt'),
      sentBackAt: time('sentBackAt'),
      doneAt: time('doneAt'),
    );
  }
}
