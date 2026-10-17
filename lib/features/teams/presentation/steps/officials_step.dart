import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/officials_editor.dart';

class OfficialsStep extends StatelessWidget {
  const OfficialsStep({
    super.key,
    required this.formKey,
    required this.showErrors,
    required this.enabled,
    required this.drafts,
    required this.onAdd,
    required this.onRemove,
  });

  final GlobalKey<FormState> formKey;
  final bool showErrors;
  final bool enabled;
  final List<OfficialDraft> drafts;
  final ValueChanged<OfficialRole> onAdd;
  final ValueChanged<OfficialDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
      autovalidateMode: showErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'The team manager and head coach are required. Phone numbers must be Ghana numbers.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                OfficialsEditor(
                  drafts: drafts,
                  enabled: enabled,
                  onAdd: onAdd,
                  onRemove: onRemove,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}