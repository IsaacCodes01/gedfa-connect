import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      ApprovalStatus.approved => (
          'Approved',
          AppColors.approvedBg,
          AppColors.approvedText,
        ),
      ApprovalStatus.pending => (
          'Pending',
          AppColors.pendingBg,
          AppColors.pendingText,
        ),
      ApprovalStatus.rejected => (
          'Rejected',
          AppColors.rejectedBg,
          AppColors.rejectedText,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}