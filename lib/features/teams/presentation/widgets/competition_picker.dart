import 'package:flutter/material.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

IconData _iconFor(Competition competition) => switch (competition) {
      Competition.division => Icons.shield_outlined,
      Competition.juvenile => Icons.groups_outlined,
    };

/// The two Competition cards on step 1.
/// It is a FormField, so the Club form checks it together with the
/// text fields: no competition ticked = the form is not valid.
class CompetitionPicker extends FormField<Set<Competition>> {
 CompetitionPicker({
    super.key,
    required Set<Competition> initialValue,
    required ValueChanged<Set<Competition>> onChanged,
    super.enabled,
  }) : super(
          initialValue: initialValue,
          validator: (value) => (value == null || value.isEmpty)
              ? 'Choose at least one competition.'
              : null,
          builder: (field) {
            void toggle(Competition competition) {
              final next = <Competition>{...?field.value};
              if (!next.remove(competition)) next.add(competition);
              field.didChange(next);
              onChanged(next);
            }

            return _PickerBody(
              selected: field.value ?? const {},
              enabled: field.widget.enabled,
              errorText: field.errorText,
              onToggle: toggle,
            );
          },
        );
}

class _PickerBody extends StatelessWidget {
  const _PickerBody({
    required this.selected,
    required this.enabled,
    required this.errorText,
    required this.onToggle,
  });

  final Set<Competition> selected;
  final bool enabled;
  final String? errorText;
  final ValueChanged<Competition> onToggle;

  String get _summary {
    final division = selected.contains(Competition.division);
    final juvenile = selected.contains(Competition.juvenile);
    if (division && juvenile) {
      return 'Your club will have a senior side and a youth side.';
    }
    if (juvenile) return 'Your club will have U13, U15 and U17 squads.';
    return 'Your club will play in the Third Division.';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final error = errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Competitions',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        Text(
          'Choose one or both',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        for (final competition in Competition.values) ...[
          _CompetitionCard(
            competition: competition,
            selected: selected.contains(competition),
            onTap: enabled ? () => onToggle(competition) : null,
          ),
          const SizedBox(height: 10),
        ],
        if (error != null)
          Text(
            error,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w500,
            ),
          )
        else if (selected.isNotEmpty)
          Text(
            _summary,
            style:
                textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({
    required this.competition,
    required this.selected,
    required this.onTap,
  });

  final Competition competition;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);

    return Semantics(
      button: true,
      checked: selected,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconFor(competition), color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        competition.label,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        competition.description,
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if (competition == Competition.juvenile) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final group in Competition.juvenileAgeGroups)
                              _SmallChip(label: group),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: selected
                        ? null
                        : Border.all(color: scheme.outline, width: 2),
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded,
                          size: 16, color: scheme.onPrimary)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Read-only chips for Review and Status, e.g. "Division" and
/// "Juvenile · U13 · U15 · U17".
class CompetitionChips extends StatelessWidget {
  const CompetitionChips({
    super.key,
    required this.competitions,
    this.compact = false,
    this.center = false,
  });

  final Set<Competition> competitions;
  final bool compact;
  final bool center;

  String _text(Competition competition) {
    if (competition != Competition.juvenile) return competition.label;
    return compact
        ? 'Juvenile · U13–U17'
        : 'Juvenile · ${Competition.juvenileAgeGroups.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        );

    return Wrap(
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final competition in Competition.values)
          if (competitions.contains(competition))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(competition), size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(_text(competition), style: style),
                ],
              ),
            ),
      ],
    );
  }
}