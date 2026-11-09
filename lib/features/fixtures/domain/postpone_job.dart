import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/features/fixtures/domain/postpone_plan.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// One match of a postpone: where its kick-off was and where it goes.
class PostponeMove {
  const PostponeMove({required this.id, required this.from, required this.to});

  final String id;
  final DateTime from;
  final DateTime to;

  Map<String, dynamic> toMap() => {
    'id': id,
    'from': Timestamp.fromDate(from),
    'to': Timestamp.fromDate(to),
  };

  static PostponeMove? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final from = (raw['from'] as Timestamp?)?.toDate();
    final to = (raw['to'] as Timestamp?)?.toDate();
    if (id is! String || from == null || to == null) return null;
    return PostponeMove(id: id, from: from, to: to);
  }
}

/// `postponeJobs/{competitionId}` (3.0c1d, mockups C12 to C15): a league's
/// postpone, saved before any match moves and ticked off as they do, so a
/// postpone that stopped can be finished later, on any phone or laptop, and
/// no match moves twice. Each move has its new kick-off written down, so
/// running it again only sets the same date again. Deleted when finished.
class PostponeJob {
  const PostponeJob({
    required this.competitionId,
    required this.season,
    required this.category,
    required this.name,
    required this.days,
    required this.reason,
    required this.moves,
    required this.done,
    required this.byName,
    this.startedAt,
  });

  /// The job for [plan] (with its days picked), before anything moves.
  factory PostponeJob.fromPlan(
    PostponePlan plan, {
    required String name,
    required String reason,
    required String byName,
  }) => PostponeJob(
    competitionId: plan.first.competitionId,
    season: plan.first.season,
    category: plan.first.category,
    name: name,
    days: plan.days,
    reason: reason.trim(),
    moves: [
      for (final f in plan.moving)
        PostponeMove(id: f.id, from: f.kickoffAt!, to: plan.newKickoff(f)),
    ],
    done: const {},
    byName: byName,
  );

  final String competitionId;
  final String season;
  final Competition category;

  /// "Division League"
  final String name;
  final int days;
  final String reason;

  /// By kick-off, first match first.
  final List<PostponeMove> moves;

  /// The matches already moved (or skipped: changed by hand since).
  final Set<String> done;
  final String byName;

  /// Null for a moment while the server sets the time.
  final DateTime? startedAt;

  int get movedCount => moves.where((m) => done.contains(m.id)).length;
  bool get allMoved => movedCount == moves.length;
  List<PostponeMove> get left => [
    for (final m in moves)
      if (!done.contains(m.id)) m,
  ];

  /// What the app writes when the job starts (without who and when).
  Map<String, dynamic> toMap() => {
    'season': season,
    'competitionId': competitionId,
    'category': category.name,
    'name': name,
    'days': days,
    'reason': reason,
    'moves': [for (final m in moves) m.toMap()],
    'done': [for (final id in done) id],
    'byName': byName,
  };

  static PostponeJob? fromMap(String id, Map<String, dynamic> data) {
    final category = Competition.fromString(data['category'] as String?);
    if (category == null) return null;
    return PostponeJob(
      competitionId: id,
      season: data['season'] as String? ?? '',
      category: category,
      name: data['name'] as String? ?? '',
      days: (data['days'] as num?)?.toInt() ?? 0,
      reason: data['reason'] as String? ?? '',
      moves: [
        for (final m in data['moves'] as List<dynamic>? ?? const [])
          ?PostponeMove.fromMap(m),
      ],
      done: {
        for (final d in data['done'] as List<dynamic>? ?? const [])
          if (d is String) d,
      },
      byName: data['byName'] as String? ?? '',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
    );
  }
}
