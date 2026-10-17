import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/constants/kit_colors.dart';

class KitColorPicker extends StatelessWidget {
  const KitColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color? selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final kitColor in kitColors)
          _Swatch(
            kitColor: kitColor,
            isSelected: kitColor.color == selected,
            onTap: () => onSelected(kitColor.color),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.kitColor,
    required this.isSelected,
    required this.onTap,
  });

  final KitColor kitColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checkColor = kitColor.color.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    return Tooltip(
      message: kitColor.name,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: kitColor.name,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kitColor.color,
              shape: BoxShape.circle,
                            border: Border.all(
                color: isSelected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.25),
                width: isSelected ? 3 : 1.5,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check_rounded, size: 20, color: checkColor)
                : null,
          ),
        ),
      ),
    );
  }
}