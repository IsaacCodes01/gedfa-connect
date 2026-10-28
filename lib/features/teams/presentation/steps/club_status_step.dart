import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/files/picked_document.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/features/teams/domain/club_status.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/choice_card.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/file_upload_row.dart';

/// Step 2 (board R1): already in the district, or a new club?
/// A new club adds its last league and a letter to the chairman.
/// Anyone may add a licence (photo or PDF).
class ClubStatusStep extends StatelessWidget {
  const ClubStatusStep({
    super.key,
    required this.formKey,
    required this.showErrors,
    required this.enabled,
    required this.status,
    required this.onStatusChanged,
    required this.lastLeague,
    required this.letter,
    required this.letterUrl,
    required this.onPickLetter,
    required this.licence,
    required this.licenceUrl,
    required this.licenceIsPdf,
    required this.onPickLicence,
    required this.onRemoveLicence,
  });

  final GlobalKey<FormState> formKey;
  final bool showErrors;
  final bool enabled;
  final ClubStatus status;
  final ValueChanged<ClubStatus> onStatusChanged;
  final TextEditingController lastLeague;

  /// A newly picked letter, or the one already uploaded (when editing).
  final PickedDocument? letter;
  final String? letterUrl;
  final VoidCallback onPickLetter;

  final PickedDocument? licence;
  final String? licenceUrl;
  final bool licenceIsPdf;
  final VoidCallback onPickLicence;
  final VoidCallback onRemoveLicence;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA);
    const gap = SizedBox(height: 14);

    final letter = this.letter;
    final hasLetter = letter != null || letterUrl != null;
    final licence = this.licence;
    final hasLicence = licence != null || licenceUrl != null;

    return Form(
      key: formKey,
      autovalidateMode: showErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StepHeading('Is your club already in Gomoa East?', top: 2),
                RadioGroup<ClubStatus>(
                  groupValue: status,
                  onChanged: (value) {
                    if (enabled && value != null) onStatusChanged(value);
                  },
                  child: Column(
                    children: [
                      for (final option in ClubStatus.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ChoiceCard<ClubStatus>(
                            value: option,
                            selected: status == option,
                            title: option.label,
                            description: option.description,
                            onTap: enabled
                                ? () => onStatusChanged(option)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                if (status == ClubStatus.newClub) ...[
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: lastLeague,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'League you played in last season *',
                      hintText: 'e.g. Awutu Senya Division Three',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter the league you played in'
                        : null,
                  ),
                  gap,
                  FileUploadRow(
                    title: 'Letter to the GEDFA chairman *',
                    subtitle: letter != null
                        ? '${letter.name} · ${letter.sizeText}'
                        : letterUrl != null
                            ? 'Uploaded · PDF'
                            : showErrors
                                ? 'Upload your letter to continue · PDF'
                                : 'Your request to join the district · '
                                    'PDF, up to 5 MB',
                    buttonLabel: hasLetter ? 'Change' : 'Upload PDF',
                    hasFile: hasLetter,
                    showError: showErrors && !hasLetter,
                    onPressed: enabled ? onPickLetter : null,
                  ),
                ],
                const StepHeading('Club licence (optional)', top: 22),
                FileUploadRow(
                  title: 'Licence',
                  subtitle: licence != null
                      ? '${licence.name} · ${licence.sizeText}'
                      : licenceUrl != null
                          ? 'Uploaded · ${licenceIsPdf ? 'PDF' : 'photo'}'
                          : 'If you have one · photo or PDF',
                  buttonLabel: hasLicence ? 'Change' : 'Add file',
                  isPdf: licence?.isPdf ?? (licenceUrl != null && licenceIsPdf),
                  hasFile: hasLicence,
                  onPressed: enabled ? onPickLicence : null,
                  onRemove: hasLicence && enabled ? onRemoveLicence : null,
                ),
                gap,
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Already in the district? You don't need a letter. "
                          'New clubs: the FA reads your letter before '
                          'approving.',
                          style: textTheme.bodySmall
                              ?.copyWith(fontSize: 12.5, height: 1.5),
                        ),
                      ),
                    ],
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
