import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';

/// The FA's green, light and dark.
({Color ink, Color bg, Color line}) feeGreens(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? (
            ink: const Color(0xFF7BE3B0),
            bg: const Color(0xFF123D2B),
            line: const Color(0xFF2E7D57),
          )
        : (
            ink: const Color(0xFF00502F),
            bg: const Color(0xFFE3F2EA),
            line: const Color(0xFF1E8E5A),
          );

/// The green bar: how much of the season fee is confirmed.
class FeeBar extends StatelessWidget {
  const FeeBar({super.key, required this.summary, this.height = 8});

  final FeeSummary summary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: summary.progress,
        minHeight: height,
        color: feeGreens(context).line,
        backgroundColor: scheme.outline.withValues(alpha: 0.4),
        semanticsLabel: 'Season fee paid',
        semanticsValue:
            '${cedis(summary.confirmed)} of ${cedis(summary.fee)}',
      ),
    );
  }
}
