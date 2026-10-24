import 'package:cloud_firestore/cloud_firestore.dart';

/// Who an announcement is for. Must match the rules.
enum Audience {
  everyone('Everyone', 'All teams, referees and the FA'),
  teams('All teams', 'All team managers'),
  division('Division teams', 'Division team managers'),
  juvenile('Juvenile teams', 'Juvenile team managers'),
  referees('Referees', 'All referees');

  const Audience(this.label, this.reach);
  final String label;
  final String reach;

  static Audience fromString(String? value) => values.firstWhere(
        (a) => a.name == value,
        orElse: () => Audience.everyone,
      );
}

/// `announcements/{id}`: one-way message from the FA.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.to,
    required this.important,
    required this.pinned,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final Audience to;
  final bool important;
  final bool pinned;
  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    return Announcement(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      to: Audience.fromString(data['to'] as String?),
      important: data['important'] == true,
      pinned: data['pinned'] == true,
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
