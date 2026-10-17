import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/logo_picker.dart';

class ClubStep extends StatelessWidget {
  const ClubStep({
    super.key,
    required this.formKey,
    required this.showErrors,
    required this.enabled,
    required this.teamName,
    required this.shortName,
    required this.town,
    required this.homeGround,
    required this.directions,
    required this.yearFounded,
    required this.email,
    required this.logoBytes,
    required this.logoColor,
    required this.teamNameValidator,
    required this.onTeamNameChanged,
    required this.onShortNameEdited,
    required this.onLogoPicked,
    required this.onLogoRemoved,
    this.logoUrl,
  });

  final GlobalKey<FormState> formKey;
  final bool showErrors;
  final bool enabled;
  final TextEditingController teamName;
  final TextEditingController shortName;
  final TextEditingController town;
  final TextEditingController homeGround;
  final TextEditingController directions;
  final TextEditingController yearFounded;
  final TextEditingController email;
  final Uint8List? logoBytes;
  final Color logoColor;
  final FormFieldValidator<String> teamNameValidator;
  final ValueChanged<String> onTeamNameChanged;
  final VoidCallback onShortNameEdited;
  final void Function(Uint8List bytes, String contentType) onLogoPicked;
  final VoidCallback onLogoRemoved;
  final String? logoUrl;

  static String? _shortNameValidator(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z]{3,4}$').hasMatch(text)) return '3 or 4 letters';
    return null;
  }

  static String? _yearValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    if (year == null || year < 1900 || year > DateTime.now().year) {
      return 'Enter a real year';
    }
    return null;
  }

  static String? _optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return Validators.email(value);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 16);

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
                TextFormField(
                  controller: teamName,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Team name',
                    hintText: 'e.g. Gomoa United FC',
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: onTeamNameChanged,
                  validator: teamNameValidator,
                ),
                gap,
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: LogoPicker(
                    label: initialsFor(teamName.text),
                    color: logoColor,
                    bytes: logoBytes,
                    enabled: enabled,
                    onPicked: onLogoPicked,
                    onRemoved: onLogoRemoved,
                  ),
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: shortName,
                        enabled: enabled,
                        decoration:
                            const InputDecoration(labelText: 'Short name'),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (_) => onShortNameEdited(),
                        validator: _shortNameValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Suggested from the team name. Used on fixtures and the league table.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ),
                gap,
                TextFormField(
                  controller: town,
                  enabled: enabled,
                  decoration:
                      const InputDecoration(labelText: 'Town / community'),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      Validators.requiredField(value, 'the town'),
                ),
                gap,
                TextFormField(
                  controller: homeGround,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Home ground',
                    hintText: 'e.g. Fetteh Park',
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      Validators.requiredField(value, 'the home ground'),
                ),
                gap,
                TextFormField(
                  controller: directions,
                  enabled: enabled,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Directions to the ground (optional)',
                    hintText: 'e.g. Behind the Methodist school',
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: yearFounded,
                        enabled: enabled,
                        decoration: const InputDecoration(
                          labelText: 'Founded',
                          hintText: '2015',
                          helperText: 'Optional',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: _yearValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: email,
                        enabled: enabled,
                        decoration: const InputDecoration(
                          labelText: 'Team email',
                          helperText: 'Optional',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _optionalEmail,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}