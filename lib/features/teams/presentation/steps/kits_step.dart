import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_preview.dart';

class KitsStep extends StatelessWidget {
  const KitsStep({
    super.key,
    required this.kits,
    required this.showErrors,
    required this.enabled,
    required this.onEdit,
    required this.onRemove,
  });

  final Map<KitSlot, Kit?> kits;
  final bool showErrors;
  final bool enabled;
  final ValueChanged<KitSlot> onEdit;
  final ValueChanged<KitSlot> onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tap a kit to set its colours. Home, away and goalkeeper kits are required. Referees use these to spot kit clashes.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final slot in KitSlot.values)
                        SizedBox(
                          width: tileWidth,
                          child: _KitTile(
                            slot: slot,
                            kit: kits[slot],
                            showError: showErrors,
                            enabled: enabled,
                            onTap: () => onEdit(slot),
                            onRemove: () => onRemove(slot),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KitTile extends StatelessWidget {
  const _KitTile({
    required this.slot,
    required this.kit,
    required this.showError,
    required this.enabled,
    required this.onTap,
    required this.onRemove,
  });

  final KitSlot slot;
  final Kit? kit;
  final bool showError;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doneColor = isDark ? AppColors.darkGreen : AppColors.approvedText;

    final hasKit = kit != null;
    final isMissingRequired = !hasKit && slot.isRequired;
    final highlightError = isMissingRequired && showError;

    final (statusText, statusColor) = hasKit
        ? ('Done', doneColor)
        : slot.isRequired
            ? (
                'Required · tap to set',
                highlightError ? scheme.error : scheme.onSurfaceVariant,
              )
            : ('Optional · tap to add', scheme.onSurfaceVariant);

    return Material(
      color: hasKit || slot.isRequired ? scheme.surface : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlightError ? scheme.error : scheme.outline,
          width: highlightError ? 2 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Column(
            children: [
              if (hasKit)
                KitPreview(kit: kit!, width: 70, semanticLabel: slot.label)
              else
                KitOutline(
                  width: 70,
                  color: highlightError
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              const SizedBox(height: 8),
              Text(
                slot.label,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasKit) ...[
                    Icon(Icons.check_rounded, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style:
                          textTheme.labelSmall?.copyWith(color: statusColor),
                    ),
                  ),
                ],
              ),
              if (hasKit && !slot.isRequired)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 36)),
                  onPressed: enabled ? onRemove : null,
                  child: const Text('Remove'),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}