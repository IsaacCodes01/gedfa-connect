import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/constants/kit_colors.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';

/// Step 5 (board R5): the club's home and away colours, a main and a
/// second colour each. They look different from the kit screens on
/// purpose: round badges and colour dots, no shirts.
class ColoursStep extends StatelessWidget {
  const ColoursStep({
    super.key,
    required this.colours,
    required this.initials,
    required this.enabled,
    required this.onChanged,
  });

  final TeamColours colours;

  /// e.g. "GU", inside the badge
  final String initials;
  final bool enabled;
  final ValueChanged<TeamColours> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  "Your club's colours, used to spot kit clashes on match "
                  "day and wherever your logo can't load. Filled in from "
                  'your designed kits; check them if you uploaded photos.',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ColourCard(
                title: 'Home colours',
                pair: colours.home,
                initials: initials,
                enabled: enabled,
                onChanged: (pair) => onChanged(colours.copyWith(home: pair)),
              ),
              const SizedBox(height: 14),
              _ColourCard(
                title: 'Away colours',
                pair: colours.away,
                initials: initials,
                enabled: enabled,
                onChanged: (pair) => onChanged(colours.copyWith(away: pair)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A badge (main colour with a ring in the second), a 3 : 1 colour bar
/// and two rows of colour dots.
class _ColourCard extends StatelessWidget {
  const _ColourCard({
    required this.title,
    required this.pair,
    required this.initials,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final ColourPair pair;
  final String initials;
  final bool enabled;
  final ValueChanged<ColourPair> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final textOnMain = pair.main.computeLuminance() > 0.5
        ? const Color(0xFF111111)
        : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pair.main,
                    shape: BoxShape.circle,
                    border: Border.all(color: pair.second, width: 4),
                  ),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: textOnMain,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 10,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ColoredBox(color: pair.main),
                              ),
                              Expanded(
                                child: ColoredBox(color: pair.second),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Swatches(
            label: 'Main colour',
            selected: pair.main,
            enabled: enabled,
            onSelected: (color) => onChanged(pair.copyWith(main: color)),
          ),
          const SizedBox(height: 14),
          _Swatches(
            label: 'Second colour',
            selected: pair.second,
            enabled: enabled,
            onSelected: (color) => onChanged(pair.copyWith(second: color)),
          ),
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final Color selected;
  final bool enabled;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kitColor in kitColors)
              Tooltip(
                message: kitColor.name,
                child: Semantics(
                  button: true,
                  selected: kitColor.color == selected,
                  label: '$label: ${kitColor.name}',
                  child: InkWell(
                    onTap: enabled ? () => onSelected(kitColor.color) : null,
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kitColor.color,
                        shape: BoxShape.circle,
                        border: kitColor.color.computeLuminance() > 0.8
                            ? Border.all(color: scheme.outline)
                            : null,
                        // The chosen dot gets a blue ring with a gap.
                        // Shadows paint in order: the ring first, the gap
                        // on top of it.
                        boxShadow: kitColor.color == selected
                            ? [
                                BoxShadow(
                                  color: scheme.primary,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: scheme.surface,
                                  spreadRadius: 3,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
