import 'package:flutter/material.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_color_picker.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_preview.dart';

class KitEditor extends StatelessWidget {
  const KitEditor({
    super.key,
    required this.title,
    required this.kit,
    required this.onChanged,
    this.errorText,
    this.showPreview = true,
  });

  final String title;
  final Kit kit;
  final ValueChanged<Kit> onChanged;
  final String? errorText;
  final bool showPreview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(text, style: textTheme.titleSmall),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: errorText != null ? scheme.error : scheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      if (showPreview) ...[
            Text(
              title,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Center(
              child: KitPreview(
                kit: kit,
                width: 96,
                semanticLabel: '$title preview',
              ),
            ),
          ],
          label('Shirt colour'),
          KitColorPicker(
            selected: kit.primary,
            onSelected: (color) => onChanged(kit.copyWith(primary: color)),
          ),
          label('Pattern'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pattern in KitPattern.values)
                ChoiceChip(
                  label: Text(pattern.label),
                  selected: kit.pattern == pattern,
                  onSelected: (_) => onChanged(
                    kit.copyWith(
                      pattern: pattern,
                      clearSecondary: pattern == KitPattern.plain,
                    ),
                  ),
                ),
            ],
          ),
          if (kit.needsSecondary) ...[
            label('Second colour'),
            KitColorPicker(
              selected: kit.secondary,
              onSelected: (color) =>
                  onChanged(kit.copyWith(secondary: color)),
            ),
            
          ],
          
                    label('Trims (optional)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Shoulder stripes'),
                selected: kit.shoulderStripes,
                onSelected: (on) =>
                    _changeTrim(kit.copyWith(shoulderStripes: on)),
              ),
              FilterChip(
                label: const Text('Collar & cuffs'),
                selected: kit.collarAndCuffs,
                onSelected: (on) =>
                    _changeTrim(kit.copyWith(collarAndCuffs: on)),
              ),
              FilterChip(
                label: const Text('Shorts side stripe'),
                selected: kit.shortsStripe,
                onSelected: (on) =>
                    _changeTrim(kit.copyWith(shortsStripe: on)),
              ),
            ],
          ),
          if (kit.hasTrim) ...[
            label('Trim colour'),
            KitColorPicker(
              selected: kit.trim,
              onSelected: (color) => onChanged(kit.copyWith(trim: color)),
            ),
          ],

          label('Shorts colour'),
          KitColorPicker(
            selected: kit.shorts,
            onSelected: (color) => onChanged(kit.copyWith(shorts: color)),
          ),
          label('Socks colour'),
          KitColorPicker(
            selected: kit.socks,
            onSelected: (color) => onChanged(kit.copyWith(socks: color)),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              errorText!,
              style: textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }

    void _changeTrim(Kit next) {
    onChanged(next.hasTrim ? next : next.copyWith(clearTrim: true));
  }
}