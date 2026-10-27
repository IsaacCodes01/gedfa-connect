import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/officials_editor.dart';

/// Step 3 (board R2): team manager and head coach, plus up to 5 more.
class OfficialsStep extends StatelessWidget {
  const OfficialsStep({
    super.key,
    required this.showErrors,
    required this.enabled,
    required this.drafts,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final bool showErrors;
  final bool enabled;
  final List<OfficialDraft> drafts;
  final ValueChanged<OfficialDraft> onAdd;
  final ValueChanged<OfficialDraft> onRemove;
  final VoidCallback onChanged;

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
                  'Team manager and head coach are required. Add up to 5 '
                  'more (7 in total).',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OfficialsEditor(
                drafts: drafts,
                showErrors: showErrors,
                enabled: enabled,
                onAdd: onAdd,
                onRemove: onRemove,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
