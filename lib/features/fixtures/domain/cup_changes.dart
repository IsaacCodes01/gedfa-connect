import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup_format.dart';

/// `cups/{cupId}/history/{lineId}`: one line in a cup's history (3.0c1b,
/// mockup C7), e.g. "Each round: one match → home and away", with who and
/// when. Deleted with the cup.
class CupHistoryLine {
  const CupHistoryLine({
    required this.id,
    required this.text,
    required this.byName,
    this.at,
  });

  final String id;
  final String text;
  final String byName;

  /// Null for a moment while the server sets the time.
  final DateTime? at;

  static CupHistoryLine fromMap(String id, Map<String, dynamic> data) =>
      CupHistoryLine(
        id: id,
        text: data['text'] as String? ?? '',
        byName: data['byName'] as String? ?? '',
        at: (data['at'] as Timestamp?)?.toDate(),
      );
}

/// "Cup made" / "Gala made": the first line of every history.
String cupMadeLine(Cup cup) => '${cup.kind.label} made';

/// What the FA changed, one line each, for the history. [nameOf] gives a
/// side's name ("Ojobi Stars", or "Ojobi Stars · U17" in an open cup).
/// Empty when nothing changed.
List<String> cupChanges(
  Cup before,
  Cup after, {
  required String Function(CupEntry entry) nameOf,
}) {
  final lines = <String>[];
  void line(String what, String from, String to) {
    if (from != to) lines.add('$what: $from → $to');
  }

  line('Name', before.name.trim(), after.name.trim());
  line('Type', before.kind.label, after.kind.label);
  line('Who plays', before.whoLabel, after.whoLabel);
  if (before.whoLabel == after.whoLabel) {
    final was = {for (final e in before.entries) e.key: e};
    final now = {for (final e in after.entries) e.key: e};
    final out = [
      for (final e in before.entries)
        if (!now.containsKey(e.key)) nameOf(e),
    ];
    final back = [
      for (final e in after.entries)
        if (!was.containsKey(e.key)) nameOf(e),
    ];
    if (out.isNotEmpty) lines.add('Teams: ${out.join(', ')} left out');
    if (back.isNotEmpty) lines.add('Teams: ${back.join(', ')} in');
  } else {
    line('Teams', '${before.entries.length}', '${after.entries.length}');
  }
  line('Format', formatLabel(before), formatLabel(after));
  line('Each round', legsLabel(before.legs), legsLabel(after.legs));
  line('Level at the end', before.level.label, after.level.label);
  if (after.format == CupFormat.knockout) {
    line(
      'Bracket fixed from',
      bracketFromLabel(before.bracketFrom),
      bracketFromLabel(after.bracketFrom),
    );
  }
  line('Seeding', before.seeded ? 'on' : 'off', after.seeded ? 'on' : 'off');

  final (b, a) = (before.gala, after.gala);
  if (b != null && a != null) {
    line('Ground', b.ground.trim(), a.ground.trim());
    line('Days', galaDays(b), galaDays(a));
    line('First kick-off', galaKickoff(b), galaKickoff(a));
    line('Between kick-offs', '${b.gapMinutes} min', '${a.gapMinutes} min');
  }
  return lines;
}

/// "Straight knockout", "Knockout with a first round" or "Groups, then
/// knockout"
String formatLabel(Cup cup) {
  if (cup.format == CupFormat.groups) return 'Groups, then knockout';
  return cup.entries.length >= 2 &&
          KnockoutPlan(cup.entries.length).firstRoundTies > 0
      ? 'Knockout with a first round'
      : 'Straight knockout';
}

String legsLabel(int legs) => legs == 2 ? 'home and away' : 'one match';

/// "the start" or "quarter-finals"
String bracketFromLabel(int teamsLeft) =>
    teamsLeft == 0 ? 'the start' : roundName(teamsLeft).toLowerCase();

/// "Sat 29 Aug – Sun 30 Aug" (or one day)
String galaDays(GalaSettings gala) {
  final first = formatShortDate(gala.firstDay);
  final last = formatShortDate(gala.lastDay);
  return first == last ? first : '$first – $last';
}

/// "9:00 am"
String galaKickoff(GalaSettings gala) =>
    formatTime(DateTime(2000, 1, 1, gala.kickoffHour, gala.kickoffMinute));
