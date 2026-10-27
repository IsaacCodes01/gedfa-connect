import 'package:flutter/material.dart';

class KitColor {
  const KitColor(this.name, this.color);

  final String name;
  final Color color;
}

const kitColors = <KitColor>[
  KitColor('White', Color(0xFFFFFFFF)),
  KitColor('Black', Color(0xFF111111)),
  KitColor('Grey', Color(0xFF8A8D91)),
  KitColor('Red', Color(0xFFD71920)),
  KitColor('Maroon', Color(0xFF7A1F2B)),
  KitColor('Pink', Color(0xFFE85A9A)),
  KitColor('Orange', Color(0xFFF26B1D)),
  KitColor('Yellow', Color(0xFFFFD100)),
  KitColor('Gold', Color(0xFFC9A227)),
  KitColor('Green', Color(0xFF009A44)),
  KitColor('Dark green', Color(0xFF00573F)),
  KitColor('Sky blue', Color(0xFF6CB4EE)),
  KitColor('Blue', Color(0xFF1E5BC6)),
  KitColor('Navy', Color(0xFF14213D)),
  KitColor('Purple', Color(0xFF5B2A86)),
  KitColor('Brown', Color(0xFF6B4226)),
];

/// "Red", or the hex code for a colour that isn't in the list.
String kitColorName(Color color) {
  for (final kitColor in kitColors) {
    if (kitColor.color.toARGB32() == color.toARGB32()) return kitColor.name;
  }
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
