import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/utils/color_hex.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';

/// A main and a second colour, e.g. red with white.
class ColourPair {
  const ColourPair({required this.main, required this.second});

  final Color main;
  final Color second;

  ColourPair copyWith({Color? main, Color? second}) =>
      ColourPair(main: main ?? this.main, second: second ?? this.second);

  Map<String, dynamic> toMap() => {
        'main': colorToHex(main),
        'second': colorToHex(second),
      };

  static ColourPair? fromMap(Map<String, dynamic>? map) {
    final main = colorFromHex(map?['main'] as String?);
    final second = colorFromHex(map?['second'] as String?);
    if (main == null || second == null) return null;
    return ColourPair(main: main, second: second);
  }

  /// From a designed kit: the shirt, and its pattern colour or the shorts.
  /// Photo kits have no colours to read, so they give null.
  static ColourPair? fromKit(Kit? kit) {
    if (kit == null || kit.isPhotos) return null;
    final second = kit.secondary ?? kit.shorts;
    return ColourPair(
      main: kit.primary,
      // A white shirt with white shorts: use black as the second colour
      second: second == kit.primary ? _contrastFor(kit.primary) : second,
    );
  }

  static Color _contrastFor(Color color) => color.computeLuminance() > 0.5
      ? const Color(0xFF111111)
      : const Color(0xFFFFFFFF);
}

/// The club's colours (2.13b, board R5): home and away, each a main and
/// a second colour. Used to spot kit clashes on match day and wherever
/// the logo can't load.
class TeamColours {
  const TeamColours({required this.home, required this.away});

  final ColourPair home;
  final ColourPair away;

  /// Before the club chooses: taken from the designed kits, otherwise
  /// red / white at home and white / red away.
  factory TeamColours.suggested({Kit? homeKit, Kit? awayKit}) => TeamColours(
        home: ColourPair.fromKit(homeKit) ??
            const ColourPair(
              main: Color(0xFFD71920),
              second: Color(0xFFFFFFFF),
            ),
        away: ColourPair.fromKit(awayKit) ??
            const ColourPair(
              main: Color(0xFFFFFFFF),
              second: Color(0xFFD71920),
            ),
      );

  TeamColours copyWith({ColourPair? home, ColourPair? away}) =>
      TeamColours(home: home ?? this.home, away: away ?? this.away);

  Map<String, dynamic> toMap() => {
        'home': home.toMap(),
        'away': away.toMap(),
      };

  static TeamColours? fromMap(Map<String, dynamic>? map) {
    final home = ColourPair.fromMap(map?['home'] as Map<String, dynamic>?);
    final away = ColourPair.fromMap(map?['away'] as Map<String, dynamic>?);
    if (home == null || away == null) return null;
    return TeamColours(home: home, away: away);
  }
}
