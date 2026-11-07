import 'package:flutter/material.dart';

/// Small gold "Previously Golden Unity FC" for a renamed team (2.10c).
class PreviousNamePill extends StatelessWidget {
  const PreviousNamePill({super.key, required this.name, this.maxWidth = 150});

  final String name;

  /// Long names are cut with "…" so the tile keeps room for the new name
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Previously $name',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
