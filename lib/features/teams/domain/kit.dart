import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/utils/color_hex.dart';

enum KitPattern {
  plain,
  stripes,
  hoops,
  halves,
  sash;

  static KitPattern fromString(String? value) => KitPattern.values.firstWhere(
        (pattern) => pattern.name == value,
        orElse: () => KitPattern.plain,
      );

  String get label => switch (this) {
        KitPattern.plain => 'Plain',
        KitPattern.stripes => 'Stripes',
        KitPattern.hoops => 'Hoops',
        KitPattern.halves => 'Halves',
        KitPattern.sash => 'Sash',
      };
}

class Kit {
  const Kit({
    required this.primary,
    this.secondary,
    this.pattern = KitPattern.plain,
    required this.shorts,
    required this.socks,
    this.trim,
    this.shoulderStripes = false,
    this.collarAndCuffs = false,
    this.shortsStripe = false,
  });

  final Color primary;
  final Color? secondary;
  final KitPattern pattern;
  final Color shorts;
  final Color socks;
  final Color? trim;
  final bool shoulderStripes;
  final bool collarAndCuffs;
  final bool shortsStripe;

  bool get needsSecondary => pattern != KitPattern.plain;
  bool get hasTrim => shoulderStripes || collarAndCuffs || shortsStripe;

  Kit copyWith({
    Color? primary,
    Color? secondary,
    bool clearSecondary = false,
    KitPattern? pattern,
    Color? shorts,
    Color? socks,
    Color? trim,
    bool clearTrim = false,
    bool? shoulderStripes,
    bool? collarAndCuffs,
    bool? shortsStripe,
  }) {
    return Kit(
      primary: primary ?? this.primary,
      secondary: clearSecondary ? null : (secondary ?? this.secondary),
      pattern: pattern ?? this.pattern,
      shorts: shorts ?? this.shorts,
      socks: socks ?? this.socks,
      trim: clearTrim ? null : (trim ?? this.trim),
      shoulderStripes: shoulderStripes ?? this.shoulderStripes,
      collarAndCuffs: collarAndCuffs ?? this.collarAndCuffs,
      shortsStripe: shortsStripe ?? this.shortsStripe,
    );
  }

  Map<String, dynamic> toMap() => {
        'primary': colorToHex(primary),
        'secondary': secondary == null ? null : colorToHex(secondary!),
        'pattern': pattern.name,
        'shorts': colorToHex(shorts),
        'socks': colorToHex(socks),
        'trim': trim == null ? null : colorToHex(trim!),
        'shoulderStripes': shoulderStripes,
        'collarAndCuffs': collarAndCuffs,
        'shortsStripe': shortsStripe,
      };

  static Kit? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return Kit(
      primary: colorFromHex(map['primary'] as String?) ?? Colors.white,
      secondary: colorFromHex(map['secondary'] as String?),
      pattern: KitPattern.fromString(map['pattern'] as String?),
      shorts: colorFromHex(map['shorts'] as String?) ?? Colors.white,
      socks: colorFromHex(map['socks'] as String?) ?? Colors.white,
      trim: colorFromHex(map['trim'] as String?),
      shoulderStripes: map['shoulderStripes'] as bool? ?? false,
      collarAndCuffs: map['collarAndCuffs'] as bool? ?? false,
      shortsStripe: map['shortsStripe'] as bool? ?? false,
    );
  }
}