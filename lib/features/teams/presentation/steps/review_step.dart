import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/features/teams/domain/club_status.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/colour_pair_row.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_thumb.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/officials_editor.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/competition_picker.dart';

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
    required this.kitSets,
    required this.colours,
    required this.officials,
    required this.agreed,
    required this.enabled,
    required this.onAgreedChanged,
    required this.onEdit,
    required this.directions,
    required this.email,
    this.logoUrl,
    required this.competitions,
    required this.clubStatus,
    required this.lastLeague,
    this.letterName,
    this.licenceName,
  });

  final String teamName;
  final String shortName;
  final String town;
  final String homeGround;
  final String yearFounded;
  final Uint8List? logoBytes;
  final Color logoColor;
  /// One set, or Division and Juvenile for a club in both.
  final Map<Competition, Map<KitSlot, Kit?>> kitSets;
  final TeamColours? colours;
  final List<OfficialDraft> officials;
  final bool agreed;
  final bool enabled;
  final ValueChanged<bool> onAgreedChanged;
  final ValueChanged<int> onEdit;
  final String directions;
  final String email;
  final String? logoUrl;
  final Set<Competition> competitions;
  final ClubStatus clubStatus;
  final String lastLeague;

  /// The file's name, "Uploaded" when editing, or null when missing.
  final String? letterName;
  final String? licenceName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hasLogo =
        logoBytes != null || (logoUrl != null && logoUrl!.isNotEmpty);

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
                          url: logoUrl,
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
                                shortName,
                                style: textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Competitions',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    CompetitionChips(competitions: competitions),
                    const SizedBox(height: 12),
                    _ReviewRow(label: 'Team name', value: teamName),
                    _ReviewRow(label: 'Short name', value: shortName),
                    _ReviewRow(label: 'Logo', value: hasLogo ? 'Added' : ''),
                    _ReviewRow(label: 'Town', value: town),
                    _ReviewRow(label: 'Home ground', value: homeGround),
                    _ReviewRow(label: 'Directions', value: directions),
                    _ReviewRow(label: 'Founded', value: yearFounded),
                    _ReviewRow(label: 'Team email', value: email),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ReviewCard(
                title: 'Club status',
                onEdit: enabled ? () => onEdit(1) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReviewRow(label: 'Type', value: clubStatus.shortLabel),
                    if (clubStatus == ClubStatus.newClub) ...[
                      _ReviewRow(label: 'Last season', value: lastLeague),
                      _ReviewRow(label: 'Letter', value: letterName ?? ''),
                    ],
                    _ReviewRow(label: 'Licence', value: licenceName ?? ''),
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
                        label: draft.roleText,
                        value:
                            '${draft.name.text.trim()} · ${draft.phone.text.trim()}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ReviewCard(
                title: 'Kits',
                onEdit: enabled ? () => onEdit(3) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final MapEntry(key: competition, value: kits)
                        in kitSets.entries) ...[
                      if (kitSets.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            competition.label,
                            style: textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final slot in KitSlot.values)
                            if (kits[slot] case final kit?)
                              Column(
                                children: [
                                  KitThumb(
                                    kit: kit,
                                    height: kit.isPhotos ? 44 : 68,
                                    semanticLabel: slot.label,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    slot.label.replaceAll(' kit', ''),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ReviewCard(
                title: 'Colours',
                onEdit: enabled ? () => onEdit(4) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (colours case final colours?) ...[
                      ColourPairRow(label: 'Home', pair: colours.home),
                      ColourPairRow(label: 'Away', pair: colours.away),
                    ] else
                      const _ReviewRow(label: 'Colours', value: ''),
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
    final missing = value.trim().isEmpty;

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
              missing ? 'Not added' : value,
              textAlign: TextAlign.right,
              style: missing
                  ? textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    )
                  : textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}