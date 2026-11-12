import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/teams/data/correction_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/correction_request.dart';
import 'package:gedfa_connect/core/widgets/one_line.dart';

/// Team › Squad: "The FA asked you to correct" (2.11b, mockup B3). Stays
/// until the team taps "Send back to the FA"; then a short line says the
/// FA is checking it.
class CorrectionBanner extends ConsumerStatefulWidget {
  const CorrectionBanner({super.key});

  @override
  ConsumerState<CorrectionBanner> createState() => _CorrectionBannerState();
}

class _CorrectionBannerState extends ConsumerState<CorrectionBanner> {
  bool _busy = false;

  Future<void> _sendBack(CorrectionRequest request) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send back to the FA?'),
        content: Text(
          'Only once you have corrected: ${request.itemsText}. The FA '
          'checks it and tells you in the bell.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send back'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(correctionRequestRepositoryProvider)
          .sendBack(request, uid: uid);
      if (mounted) AppToast.success(context, 'Sent back to the FA.');
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(myCorrectionRequestProvider).value;
    if (request == null || !request.isOpen) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC);
    final border = isDark ? const Color(0xFF6B5A1C) : const Color(0xFFEAD27A);
    final ink = isDark ? const Color(0xFFF5D25B) : const Color(0xFF3A2C00);
    final sentBack = request.sentBackAt;

    // Sent back: the FA is checking it
    if (request.status == CorrectionStatus.sentBack) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Correction sent back to the FA'
          '${sentBack == null ? '' : ' on ${formatDayMonth(sentBack)}'}. '
          'They will check it.',
          style: textTheme.bodySmall?.copyWith(color: ink),
        ),
      );
    }

    final askedAt = request.askedAt;
    final by = [
      if (request.askedByName case final name?) '$name (FA)',
      if (askedAt != null) formatDayMonth(askedAt),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The FA asked you to correct',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in CorrectionItem.values)
            if (request.items.contains(item))
              Text(
                '•  ${item.shortLabel}',
                style: textTheme.bodyMedium?.copyWith(color: ink),
              ),
          const SizedBox(height: 6),
          Text(
            '"${request.message}"',
            style: textTheme.bodyMedium?.copyWith(color: ink),
          ),
          if (by.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(by, style: textTheme.bodySmall?.copyWith(color: ink)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => context.open(Routes.teamClub),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    backgroundColor: isDark ? null : Colors.white,
                    side: BorderSide(color: ink.withValues(alpha: 0.6)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const OneLine(Text('Team profile')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : () => _sendBack(request),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700),
                    foregroundColor:
                        isDark ? const Color(0xFF3A2C00) : Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const OneLine(Text('Send back to the FA')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
