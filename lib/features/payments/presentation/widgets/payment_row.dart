import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';

/// Colours for Confirmed (green), Waiting (gold) and Not found (red).
({Color bg, Color ink}) paymentTones(BuildContext context, PaymentStatus s) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (s) {
    PaymentStatus.confirmed => isDark
        ? (bg: const Color(0xFF123D2B), ink: const Color(0xFF7BE3B0))
        : (bg: const Color(0xFFE3F2EA), ink: const Color(0xFF00502F)),
    PaymentStatus.waiting => isDark
        ? (bg: const Color(0xFF3D3410), ink: const Color(0xFFF5D25B))
        : (bg: const Color(0xFFFFF6CC), ink: const Color(0xFF5C4700)),
    PaymentStatus.notFound => isDark
        ? (bg: const Color(0xFF4A1820), ink: const Color(0xFFFF9DA6))
        : (bg: const Color(0xFFFDE7EA), ink: const Color(0xFFA10E1F)),
  };
}

/// "GH₵ 500 · MoMo   12 Oct · receipt GEDFA-2026-0014   [CONFIRMED]"
/// (board R8).
class PaymentRow extends StatelessWidget {
  const PaymentRow({super.key, required this.payment, this.divider = true});

  final Payment payment;

  /// A line above the row (not on the first one).
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tones = paymentTones(context, payment.status);
    final amount = payment.amount;
    final when = payment.paidOn ?? payment.createdAt;

    final (IconData icon, String chip) = switch (payment.status) {
      PaymentStatus.confirmed => (Icons.check_rounded, 'Confirmed'),
      PaymentStatus.waiting => (Icons.schedule_rounded, 'Waiting'),
      PaymentStatus.notFound => (Icons.priority_high_rounded, 'Not found'),
    };

    final details = [
      if (when != null) formatDate(when),
      switch (payment.status) {
        PaymentStatus.confirmed => 'receipt ${payment.receiptNo ?? ''}',
        PaymentStatus.notFound => 'FA: "${payment.reason ?? ''}"',
        PaymentStatus.waiting => payment.reference == null
            ? 'waiting for the FA'
            : 'ID ${payment.reference}',
      },
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: scheme.outline))
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: tones.bg,
            child: Icon(icon, size: 18, color: tones.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${amount == null ? 'Amount from FA records' : cedis(amount)}'
                  ' · ${payment.method.shortLabel}',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                Text(
                  details,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: tones.bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              chip.toUpperCase(),
              style: TextStyle(
                color: tones.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
