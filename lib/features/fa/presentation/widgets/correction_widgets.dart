import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_correction_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team_correction.dart';

// FA corrections (2.11a, mockups A1, A2b, A4).

/// "Home ground: Apam Prk → Apam Park" (empty values read "nothing").
String correctionLine(String label, String? from, String? to) {
  String shown(String? value) =>
      value == null || value.trim().isEmpty ? 'nothing' : value.trim();
  return '$label: ${shown(from)} → ${shown(to)}';
}

/// The "What was wrong?" box (A2b). Shows [lines] (what changes) and
/// returns the reason, or null if the FA goes back.
Future<String?> showCorrectionReasonSheet(
  BuildContext context, {
  required String teamName,
  required List<String> lines,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true, // moves up with the keyboard
    showDragHandle: true,
    builder: (_) => _ReasonSheet(teamName: teamName, lines: lines),
  );
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.teamName, required this.lines});

  final String teamName;
  final List<String> lines;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + keyboard),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Save this correction?',
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              for (final line in widget.lines) _LogLine(line),
              const SizedBox(height: 14),
              ReasonField(controller: _reason, teamName: widget.teamName),
              const SizedBox(height: 16),
              SheetButtons(
                cancelLabel: 'Back',
                saveLabel: 'Save',
                onSave: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "What was wrong? *", 5 to 300 characters (as the rules).
class ReasonField extends StatelessWidget {
  const ReasonField({
    super.key,
    required this.controller,
    required this.teamName,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String teamName;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      minLines: 2,
      maxLines: 4,
      inputFormatters: [LengthLimitingTextInputFormatter(300)],
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'What was wrong? *',
        helperText: '$teamName sees this. 5–300 characters.',
        alignLabelWithHint: true,
      ),
      validator: (value) => (value?.trim().length ?? 0) < 5
          ? 'Write at least 5 characters'
          : null,
    );
  }
}

/// Back / Cancel (outlined) and Save (filled, twice as wide).
class SheetButtons extends StatelessWidget {
  const SheetButtons({
    super.key,
    required this.cancelLabel,
    required this.saveLabel,
    required this.onSave,
    this.busy = false,
  });

  final String cancelLabel;
  final String saveLabel;

  /// Null greys out Save
  final VoidCallback? onSave;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: busy ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(saveLabel),
          ),
        ),
      ],
    );
  }
}

// ── A4: Correct the club name ────────────────────────────────────────────

/// What the FA typed in the name box (A4).
typedef NameCorrection = ({String name, String reason});

/// The "Correct the club name" box. Returns the new spelling and why, or
/// null if cancelled. Another club's name can't be saved.
Future<NameCorrection?> showNameCorrectionSheet(
  BuildContext context, {
  required String teamId,
  required String name,
}) {
  return showModalBottomSheet<NameCorrection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NameSheet(teamId: teamId, name: name),
  );
}

class _NameSheet extends ConsumerStatefulWidget {
  const _NameSheet({required this.teamId, required this.name});

  final String teamId;

  /// The name now
  final String name;

  @override
  ConsumerState<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends ConsumerState<_NameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  final _reason = TextEditingController();
  Timer? _wait;

  /// The name the app checked, a moment after the FA stopped typing (so
  /// it doesn't read Firestore on every key).
  String? _checked;

  @override
  void dispose() {
    _wait?.cancel();
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  String get _typed => _name.text.trim();
  bool get _changed => _typed.length >= 2 && _typed != widget.name;

  void _onNameChanged(String _) {
    _wait?.cancel();
    setState(() => _checked = null);
    _wait = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _changed) setState(() => _checked = _typed);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((name: _typed, reason: _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final checked = _checked;
    final check = checked == null
        ? null
        : ref
            .watch(nameCheckProvider((teamId: widget.teamId, name: checked)))
            .value;
    // Save only once the app has checked THIS name and no club holds it
    final canSave = _changed && checked == _typed && check?.taken == false;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + keyboard),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Correct the club name',
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'For spelling mistakes. A new name is the team\'s to ask for '
                '(Team profile › Ask to change).',
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                onChanged: _onNameChanged,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(60)],
                decoration: const InputDecoration(labelText: 'Club name'),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Write the club name'
                    : null,
              ),
              if (_changed) ...[
                const SizedBox(height: 6),
                WasLine(widget.name),
              ],
              if (checked != null && check != null) ...[
                const SizedBox(height: 10),
                _NameCheckBox(check: check),
              ],
              const SizedBox(height: 14),
              ReasonField(controller: _reason, teamName: widget.name),
              const SizedBox(height: 16),
              SheetButtons(
                cancelLabel: 'Cancel',
                saveLabel: 'Save',
                onSave: canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green: free; gold: very close to another club's name (Save still
/// works); red: another club holds it (Save is off).
class _NameCheckBox extends StatelessWidget {
  const _NameCheckBox({required this.check});

  final NameCheck check;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final similarTo = check.similarTo;
    final (Color bg, Color ink, String text) = check.taken
        ? (
            isDark ? const Color(0xFF4A1820) : const Color(0xFFFDE7EA),
            isDark ? const Color(0xFFFF9AA5) : const Color(0xFF8C1022),
            'Another club holds this name. It can\'t be used.',
          )
        : similarTo != null
            ? (
                isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC),
                isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700),
                'Very close to $similarTo. Check it is not the same club. '
                    "Every player's team name follows.",
              )
            : (
                isDark ? const Color(0xFF123D2B) : const Color(0xFFE3F2EA),
                isDark ? const Color(0xFF7BE3B0) : const Color(0xFF00502F),
                "✓ Free. Every player's team name follows; player IDs "
                    "don't change.",
              );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ink),
      ),
    );
  }
}

/// "Was: ~~Apam Prk~~" under a field the FA changed.
class WasLine extends StatelessWidget {
  const WasLine(this.value, {super.key});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    final value = this.value;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Was: '),
          TextSpan(
            text: value == null || value.isEmpty ? 'nothing' : value,
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        ]),
        style: style,
      ),
    );
  }
}

// ── A1: the log on the FA's team page ────────────────────────────────────

/// Small blue "FA fixed" after a value the FA corrected.
class FaFixedPill extends StatelessWidget {
  const FaFixedPill({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'FA fixed',
        style: TextStyle(
          color: scheme.primary,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// "Corrections log": the latest 3, then "See all (n)".
class CorrectionsLog extends ConsumerStatefulWidget {
  const CorrectionsLog({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<CorrectionsLog> createState() => _CorrectionsLogState();
}

class _CorrectionsLogState extends ConsumerState<CorrectionsLog> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final corrections =
        ref.watch(teamCorrectionsProvider(widget.teamId)).value ?? const [];
    if (corrections.isEmpty) return const SizedBox.shrink();
    final shown = _all ? corrections : corrections.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        const SectionTitle('Corrections log'),
        TileGroup(
          children: [
            for (final correction in shown) _LogEntry(correction: correction),
            if (!_all && corrections.length > 3)
              TextButton(
                onPressed: () => setState(() => _all = true),
                child: Text('See all (${corrections.length})'),
              ),
          ],
        ),
      ],
    );
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry({required this.correction});

  final TeamCorrection correction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final when = correction.createdAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in correction.lines) _LogLine(line),
          const SizedBox(height: 2),
          Text(
            [
              '"${correction.reason}"',
              ?correction.byName,
              if (when != null) formatDayMonth(when),
            ].join(' · '),
            style:
                textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// "**Home ground**: Apam Prk → Apam Park"
class _LogLine extends StatelessWidget {
  const _LogLine(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    final colon = line.indexOf(': ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        colon < 0
            ? TextSpan(text: line)
            : TextSpan(children: [
                TextSpan(
                  text: line.substring(0, colon),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: line.substring(colon)),
              ]),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
