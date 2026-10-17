import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_preview.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/officials_editor.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

class ReviewStep extends StatelessWidget {
  const ReviewStep({
    super.key,
    required this.teamName,
    required this.shortName,
    required this.town,
    required this.homeGround,
    required this.yearFounded,
    required this.logoBytes,
    required this.logoColor,
    required this.kits,
    required this.officials,
    required this.agreed,
    required this.enabled,
    required this.onAgreedChanged,
    required this.onEdit,
    required this.directions,
    required this.email,
    this.logoUrl,
  });

  final String teamName;
  final String shortName;
  final String town;
  final String homeGround;
  final String yearFounded;
  final Uint8List? logoBytes;
  final Color logoColor;
  final Map<KitSlot, Kit?> kits;
  final List<OfficialDraft> officials;
  final bool agreed;
  final bool enabled;
  final ValueChanged<bool> onAgreedChanged;
  final ValueChanged<int> onEdit;
  final String directions;
  final String email;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final setKits = [
      for (final slot in KitSlot.values)
        if (kits[slot] != null) (slot, kits[slot]!),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Check everything before sending. The FA will review your registration and reply in the app.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _ReviewCard(
                title: 'Club',
                onEdit: enabled ? () => onEdit(0) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        TeamLogo(
                          label: initialsFor(teamName),
                          color: logoColor,
                          bytes: logoBytes,
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teamName,
                                style: textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                logoBytes == null
                                    ? '$shortName · no logo yet'
                                    : shortName,
                                style: textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ReviewRow(label: 'Town', value: town),
                     _ReviewRow(label: 'Short name', value: shortName),
                    _ReviewRow(label: 'Town', value: town),
                    _ReviewRow(label: 'Home ground', value: homeGround),
                    if (directions.isNotEmpty)
                      _ReviewRow(label: 'Directions', value: directions),
                    if (yearFounded.isNotEmpty)
                      _ReviewRow(label: 'Founded', value: yearFounded),
                    if (email.isNotEmpty)
                      _ReviewRow(label: 'Team email', value: email),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ReviewCard(
                title: 'Kits',
                onEdit: enabled ? () => onEdit(1) : null,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final (slot, kit) in setKits)
                      Column(
                        children: [
                          KitPreview(kit: kit, width: 52),
                          const SizedBox(height: 4),
                          Text(
                            slot.label.replaceAll(' kit', ''),
                            style: textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ReviewCard(
                title: 'Officials',
                onEdit: enabled ? () => onEdit(2) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final draft in officials)
                      _ReviewRow(
                        label: draft.role.label,
                        value:
                            '${draft.name.text.trim()} · ${draft.phone.text.trim()}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
                            Material(
                color: scheme.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outline),
                ),
                child: CheckboxListTile(
                  value: agreed,
                  onChanged: enabled
                      ? (value) => onAgreedChanged(value ?? false)
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'I confirm these details are true and our team agrees to follow the GEDFA league rules.',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.onEdit,
    required this.child,
  });

  final String title;
  final VoidCallback? onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
            ],
          ),
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}