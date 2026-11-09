import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gedfa_connect/core/utils/team_name_key.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/b_side_ring.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/choice_card.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

/// "Your juvenile side's name" (juvenile side names, mockups JS1, JS1b):
/// only for a club in both competitions. The club's name with "B" (the
/// default), or its own name and short name, with a preview of how the
/// juvenile sides show in fixtures and tables.
///
/// Put it inside a [Form]: the two fields check themselves with it.
class JuvenileNamePicker extends StatelessWidget {
  const JuvenileNamePicker({
    super.key,
    required this.clubName,
    required this.clubShortName,
    required this.ownName,
    required this.onOwnNameChanged,
    required this.name,
    required this.shortName,
    required this.enabled,
    required this.logoColor,
    this.logoBytes,
    this.logoUrl,
    this.nameError,
    this.onNameChanged,
    this.compact = false,
    this.currentName,
    this.currentShortName,
  });

  /// The club's name and short name as typed ("Royal Unique FC", "RUF")
  final String clubName;
  final String clubShortName;

  /// false = "Royal Unique FC B", true = its own name
  final bool ownName;
  final ValueChanged<bool> onOwnNameChanged;
  final TextEditingController name;
  final TextEditingController shortName;
  final bool enabled;
  final Color logoColor;
  final Uint8List? logoBytes;
  final String? logoUrl;

  /// "Another club already uses this name" (checked online on Next)
  final String? nameError;

  /// Typing in the name field (to clear [nameError])
  final ValueChanged<String>? onNameChanged;

  /// "Ask the FA to change" (mockup JS3b): just the two choices and the
  /// fields, with shorter texts; no heading, preview or note
  final bool compact;

  /// The juvenile side's own name now, if it has one: asking for the same
  /// name and short name again is refused
  final String? currentName;
  final String? currentShortName;

  String get _club => clubName.trim().isEmpty ? 'Your club' : clubName.trim();
  String get _clubShort => clubShortName.trim().toUpperCase();

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the juvenile side name';
    if (teamNameKey(text).length < 2) return 'The name is too short';
    if (text.length > 60) return 'Keep it under 60 characters';
    if (teamNameKey(text) == teamNameKey(clubName)) {
      return "Not your club's name: pick a different one, or use \"B\"";
    }
    return nameError;
  }

  String? _validateShortName(String? value) {
    final text = value?.trim().toUpperCase() ?? '';
    if (!RegExp(r'^[A-Z]{3,4}$').hasMatch(text)) return '3 or 4 letters';
    if (text == _clubShort) return "Not your club's short name ($_clubShort)";
    if (currentName != null &&
        teamNameKey(name.text) == teamNameKey(currentName!) &&
        text == currentShortName?.toUpperCase()) {
      return "This is your juvenile side's name already";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  "Your juvenile side's name",
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'U13 · U15 · U17',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        RadioGroup<bool>(
          groupValue: ownName,
          onChanged: (value) {
            if (enabled && value != null) onOwnNameChanged(value);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChoiceCard<bool>(
                value: false,
                selected: !ownName,
                title: '$_club B',
                description: compact
                    ? 'Your club\'s name with "B"'
                    : 'Your club\'s name with "B". Renamed with the club if '
                          'it is ever renamed.',
                onTap: enabled ? () => onOwnNameChanged(false) : null,
              ),
              const SizedBox(height: 8),
              ChoiceCard<bool>(
                value: true,
                selected: ownName,
                title: 'Its own name',
                description: compact
                    ? 'A different name and short name'
                    : 'A different name and short name, e.g. "Royal Unique '
                          'Colts".',
                onTap: enabled ? () => onOwnNameChanged(true) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (ownName) ...[
          _CheckedField(
            controller: name,
            enabled: enabled,
            label: 'Juvenile side name',
            helper: '2–60 characters. Not the name of another club.',
            validator: _validateName,
            capitalization: TextCapitalization.words,
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 12),
          _CheckedField(
            controller: shortName,
            enabled: enabled,
            label: 'Juvenile short name',
            helper:
                '3–4 capitals, for fixture rows and tables. Not your club\'s '
                'short name${_clubShort.isEmpty ? '' : ' ($_clubShort)'}.',
            validator: _validateShortName,
            capitalization: TextCapitalization.characters,
            formatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
              LengthLimitingTextInputFormatter(4),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (!compact)
          ListenableBuilder(
            listenable: Listenable.merge([name, shortName]),
            builder: (context, _) => _Preview(
              ownName: ownName,
              title: ownName
                  ? (name.text.trim().isEmpty
                        ? 'Your juvenile side'
                        : name.text.trim())
                  : '$_club B',
              subtitle: ownName
                  ? '${shortName.text.trim().toUpperCase()} · U13, U15 and U17'
                  : 'How your juvenile sides show in fixtures and tables',
              label: ownName ? shortName.text.trim().toUpperCase() : _clubShort,
              logoColor: logoColor,
              logoBytes: logoBytes,
              logoUrl: logoUrl,
            ),
          ),
        if (!ownName && !compact) ...[
          const SizedBox(height: 12),
          InfoBox(
            icon: Icons.info_outline_rounded,
            color: scheme.primary,
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Your Division side plays as '),
                  TextSpan(
                    text: _club,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text: '. Only clubs in both competitions choose this.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A text field with a green tick at the end once what is typed is fine
/// (mockup JS1b).
class _CheckedField extends StatelessWidget {
  const _CheckedField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.helper,
    required this.validator,
    required this.capitalization,
    this.formatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String helper;
  final FormFieldValidator<String> validator;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ok =
            controller.text.trim().isNotEmpty &&
            validator(controller.text) == null;
        return TextFormField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            helperMaxLines: 2,
            suffixIcon: ok
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF00703F),
                  )
                : null,
          ),
          textCapitalization: capitalization,
          inputFormatters: formatters,
          onChanged: onChanged,
          validator: validator,
        );
      },
    );
  }
}

/// How the juvenile sides will show: the crest (with the gold ring for
/// "B") and the name.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.ownName,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.logoColor,
    this.logoBytes,
    this.logoUrl,
  });

  final bool ownName;
  final String title;
  final String subtitle;
  final String label;
  final Color logoColor;
  final Uint8List? logoBytes;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget logo(double size) => TeamLogo(
      label: label.isEmpty ? '?' : label,
      color: logoColor,
      bytes: logoBytes,
      url: logoBytes == null ? logoUrl : null,
      size: size,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          ownName ? logo(32) : BSideRing(size: 32, builder: logo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
