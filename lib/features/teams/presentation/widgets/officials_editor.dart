import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/utils/phone.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';

class OfficialDraft {
  OfficialDraft(
    this.role, {
    String name = '',
    String phone = '',
    String licence = '',
  })  : name = TextEditingController(text: name),
        phone = TextEditingController(text: phone),
        licence = TextEditingController(text: licence);

  factory OfficialDraft.fromOfficial(Official official) => OfficialDraft(
        official.role,
        name: official.name,
        phone: official.phone,
        licence: official.licence ?? '',
      );

  final OfficialRole role;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController licence;

  Official toOfficial() {
    final licenceText = licence.text.trim();
    return Official(
      role: role,
      name: name.text.trim(),
      phone: normalizeGhanaPhone(phone.text) ?? phone.text.trim(),
      licence: role == OfficialRole.headCoach && licenceText.isNotEmpty
          ? licenceText
          : null,
    );
  }

  void dispose() {
    name.dispose();
    phone.dispose();
    licence.dispose();
  }
}

class OfficialsEditor extends StatelessWidget {
  const OfficialsEditor({
    super.key,
    required this.drafts,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  final List<OfficialDraft> drafts;
  final ValueChanged<OfficialRole> onAdd;
  final ValueChanged<OfficialDraft> onRemove;
  final bool enabled;

  Future<void> _chooseRole(
    BuildContext context,
    List<OfficialRole> available,
  ) async {
    final role = await showModalBottomSheet<OfficialRole>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final role in available)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(role.label),
                onTap: () => Navigator.pop(sheetContext, role),
              ),
          ],
        ),
      ),
    );
    if (role != null) onAdd(role);
  }

  @override
  Widget build(BuildContext context) {
    final available = OfficialRole.values
        .where((role) => !drafts.any((draft) => draft.role == role))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final draft in drafts)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _OfficialCard(
              draft: draft,
              enabled: enabled,
              onRemove: draft.role.isRequired ? null : () => onRemove(draft),
            ),
          ),
        if (available.isNotEmpty)
          OutlinedButton.icon(
            onPressed: enabled ? () => _chooseRole(context, available) : null,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Add another official'),
          ),
      ],
    );
  }
}

class _OfficialCard extends StatelessWidget {
  const _OfficialCard({
    required this.draft,
    required this.enabled,
    this.onRemove,
  });

  final OfficialDraft draft;
  final bool enabled;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
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
              Expanded(
                child: Text(
                  draft.role.label,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (onRemove == null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Required',
                    style: textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                IconButton(
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Remove ${draft.role.label.toLowerCase()}',
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: draft.name,
                  enabled: enabled,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      Validators.requiredField(value, 'their full name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: draft.phone,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '024 123 4567',
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.ghanaPhone,
                ),
                if (draft.role == OfficialRole.headCoach) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: draft.licence,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Coaching licence (optional)',
                      hintText: 'e.g. CAF D',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}