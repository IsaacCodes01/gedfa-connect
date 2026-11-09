import 'package:flutter/material.dart';

/// The thin gold ring around a "B" side's crest (juvenile side names,
/// mockup JS5): a club's juvenile side playing as "Royal Unique FC B".
/// It fits in [size], so rows keep their height; [builder] gets the size
/// left for the crest inside.
class BSideRing extends StatelessWidget {
  const BSideRing({super.key, required this.size, required this.builder});

  final double size;
  final Widget Function(double innerSize) builder;

  /// The gap and the gold ring around the crest
  static const gap = 2.0;
  static const ring = 1.5;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(gap),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: isDark ? const Color(0xFFF5D25B) : const Color(0xFF8A6A00),
          width: ring,
        ),
      ),
      child: builder(size - 2 * (gap + ring)),
    );
  }
}
