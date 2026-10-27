import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/dashed_border.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_thumb.dart';

/// The kits of one competition: home, away, goalkeeper (+ optional).
typedef KitSet = Map<KitSlot, Kit?>;

/// True when home, away and goalkeeper are all set.
bool kitSetComplete(KitSet kits) => KitSlot.values
    .where((slot) => slot.isRequired)
    .every((slot) => kits[slot] != null);

/// Step 4 (board R3): each kit is uploaded as photos or designed.
/// A club in both competitions sets Division and Juvenile kits apart.
class KitsStep extends StatefulWidget {
  const KitsStep({
    super.key,
    required this.competitions,
    required this.kits,
    required this.showErrors,
    required this.enabled,
    required this.onUpload,
    required this.onDesign,
    required this.onRemove,
  });

  final Set<Competition> competitions;
  final Map<Competition, KitSet> kits;
  final bool showErrors;
  final bool enabled;
  final void Function(Competition, KitSlot) onUpload;
  final void Function(Competition, KitSlot) onDesign;
  final void Function(Competition, KitSlot) onRemove;

  @override
  State<KitsStep> createState() => _KitsStepState();
}

class _KitsStepState extends State<KitsStep> {
  late Competition _tab = _firstTab();

  /// Open the tab that still needs kits (Division first).
  Competition _firstTab() {
    for (final competition in Competition.values) {
      if (widget.competitions.contains(competition) &&
          !kitSetComplete(widget.kits[competition] ?? const {})) {
        return competition;
      }
    }
    return Competition.values.firstWhere(widget.competitions.contains);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final both = widget.competitions.length > 1;
    // If the club changed its competitions, show one it still plays in
    final tab = widget.competitions.contains(_tab)
        ? _tab
        : widget.competitions.first;
    final kits = widget.kits[tab] ?? const {};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (both) ...[
                _Tabs(
                  selected: tab,
                  // A red dot on a tab whose kits are missing
                  needsWork: {
                    for (final c in Competition.values)
                      c: widget.showErrors &&
                          !kitSetComplete(widget.kits[c] ?? const {}),
                  },
                  onChanged: (value) => setState(() => _tab = value),
                ),
                const SizedBox(height: 12),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  both
                      ? 'Upload photos of your real kit, or design it with '
                          'our kit maker. Juvenile kits are separate.'
                      : 'Upload photos of your real kit, or design it with '
                          'our kit maker.',
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final slot in KitSlot.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _KitCard(
                    slot: slot,
                    kit: kits[slot],
                    showError: widget.showErrors,
                    enabled: widget.enabled,
                    onUpload: () => widget.onUpload(tab, slot),
                    onDesign: () => widget.onDesign(tab, slot),
                    onRemove: () => widget.onRemove(tab, slot),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Division kits | Juvenile kits"
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.needsWork,
    required this.onChanged,
  });

  final Competition selected;
  final Map<Competition, bool> needsWork;
  final ValueChanged<Competition> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segBg = isDark ? const Color(0xFF13233A) : const Color(0xFFDCE6F2);
    final segOn = isDark ? const Color(0xFF24476E) : Colors.white;
    final segOnInk = isDark ? const Color(0xFFE8EEF6) : const Color(0xFF0B3F7A);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: segBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final competition in Competition.values)
            Expanded(
              child: Semantics(
                selected: competition == selected,
                button: true,
                child: Material(
                  color: competition == selected
                      ? segOn
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => onChanged(competition),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${competition.label} kits',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: competition == selected
                                  ? segOnInk
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          if (needsWork[competition] ?? false) ...[
                            const SizedBox(width: 6),
                            CircleAvatar(
                              radius: 4,
                              backgroundColor: scheme.error,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One kit: name, "Photos" / "Designed", the kit, and the two buttons.
class _KitCard extends StatelessWidget {
  const _KitCard({
    required this.slot,
    required this.kit,
    required this.showError,
    required this.enabled,
    required this.onUpload,
    required this.onDesign,
    required this.onRemove,
  });

  final KitSlot slot;
  final Kit? kit;
  final bool showError;
  final bool enabled;
  final VoidCallback onUpload;
  final VoidCallback onDesign;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA);
    final chipInk = isDark ? const Color(0xFFCFE4FB) : const Color(0xFF0B3F7A);

    final kit = this.kit;
    final missing = kit == null && slot.isRequired && showError;
    final lineColor = missing ? scheme.error : scheme.outline;

    final buttons = Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: enabled ? onUpload : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('Upload photos'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled ? onDesign : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: scheme.outline, width: 1.5),
              foregroundColor: scheme.onSurface,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Design kit'),
          ),
        ),
      ],
    );

    final title = Row(
      children: [
        Expanded(
          child: Text(
            slot.isRequired ? '${slot.label} *' : '${slot.label} (optional)',
            style: textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        if (kit != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              kit.isPhotos ? 'PHOTOS' : 'DESIGNED',
              style: TextStyle(
                color: chipInk,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          )
        else if (missing)
          Text(
            'Required',
            style: textTheme.labelSmall?.copyWith(color: scheme.error),
          ),
      ],
    );

    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          if (kit != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: KitThumb(
                  kit: kit,
                  height: kit.isPhotos ? 74 : 72,
                  semanticLabel: slot.label,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          buttons,
          if (kit != null && !slot.isRequired)
            TextButton(
              onPressed: enabled ? onRemove : null,
              style: TextButton.styleFrom(minimumSize: const Size(0, 36)),
              child: Text('Remove ${slot.label.toLowerCase()}'),
            ),
        ],
      ),
    );

    // Set kits: a solid card. Missing ones: dashed, red when required.
    if (kit != null) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outline),
        ),
        child: content,
      );
    }
    return DashedBorder(
      color: lineColor,
      radius: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: slot.isRequired ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: content,
      ),
    );
  }
}
