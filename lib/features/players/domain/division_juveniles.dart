import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';

/// Juveniles in the Division (3.1d, mockups DJ1, DJ2; Isaac 11 Nov 2026):
/// a club in both competitions names up to 7 of its approved juvenile
/// players who may also play Division matches. At most 1 U13 and 3 U15
/// (GEDFA), U17 without a limit. They still play their juvenile matches.
/// The same limits are in firestore.rules.
class DivisionJuveniles {
  const DivisionJuveniles([this.players = const {}]);

  static const max = 7;

  /// Player ID → their age group when named.
  final Map<String, AgeGroup> players;

  /// At most this many of an age group; null = no limit (U17).
  static int? limitOf(AgeGroup group) => switch (group) {
    AgeGroup.u13 => 1,
    AgeGroup.u15 => 3,
    AgeGroup.u17 => null,
  };

  int get size => players.length;
  int get placesLeft => max - size;
  bool contains(String id) => players.containsKey(id);
  int countOf(AgeGroup group) => players.values.where((g) => g == group).length;

  bool isFull(AgeGroup group) {
    final limit = limitOf(group);
    return limit != null && countOf(group) >= limit;
  }

  /// Why [p] can't be named, or null when they can.
  String? whyNot(Player p) {
    final group = p.ageGroup;
    if (!p.isJuvenile || group == null) return 'Only juvenile players.';
    if (!p.isApproved) return 'Only approved juveniles can be named.';
    if (contains(p.id)) return '${p.fullName} is already named.';
    if (size >= max) return 'All $max places are taken: remove one first.';
    if (isFull(group)) {
      return '${group.label} limit reached: remove one first.';
    }
    return null;
  }

  static DivisionJuveniles fromMap(Map<String, dynamic>? data) {
    final raw = data?['players'];
    if (raw is! Map) return const DivisionJuveniles();
    return DivisionJuveniles({
      for (final e in raw.entries)
        if (e.key is String && AgeGroup.fromString(e.value as String?) != null)
          e.key as String: AgeGroup.fromString(e.value as String?)!,
    });
  }
}
