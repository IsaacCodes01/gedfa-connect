import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/constants/kit_colors.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';

/// "Home   ● ●  Red and white", for the review screens.
class ColourPairRow extends StatelessWidget {
  const ColourPairRow({super.key, required this.label, required this.pair});

  final String label;
  final ColourPair pair;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget dot(Color color) => Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outline),
          ),
        );

    final names =
        '${kitColorName(pair.main)} and ${kitColorName(pair.second).toLowerCase()}';

    return Semantics(
      label: '$label colours: $names',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                label,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            dot(pair.main),
            dot(pair.second),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                names,
                style: textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
