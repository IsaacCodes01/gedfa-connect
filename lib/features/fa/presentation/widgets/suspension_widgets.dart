import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/data/suspension_repository.dart';
import 'package:gedfa_connect/features/teams/domain/suspension.dart';
import 'package:gedfa_connect/core/widgets/one_line.dart';

// Suspensions (2.11c, mockups C1–C5). Chairman only.

/// Red for suspensions, readable in both themes.
({Color bg, Color border, Color ink}) suspensionColours(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? (
          bg: const Color(0xFF4A1820),
          border: const Color(0xFF7A2A36),
          ink: const Color(0xFFFF9AA5),
        )
      : (
          bg: const Color(0xFFFBE3E7),
          border: const Color(0xFFE9B7C0),
          ink: const Color(0xFF8C1022),
        );
}

/// "Since 7 Nov · until 30 Nov" or "… · until the FA board has met the club"
String suspensionPeriod(Suspension suspension) {
  final since = suspension.since;
  final lastDay = suspension.lastDay;
  return [
    if (since != null) 'Since ${formatDayMonth(since)}',
    lastDay == null
        ? 'until the FA board has met the club'
        : 'until ${formatDayMonth(lastDay)}',
  ].join(' · ');
}

/// The red banner: on the team's Squad tab (C2, [message] "Contact the
/// FA.") and on the FA's team page (C3, with Lift for the chairman).
class SuspendedBanner extends StatelessWidget {
  const SuspendedBanner({
    super.key,
    required this.title,
    required this.suspension,
    this.message,
    this.onLift,
  });

  final String title;
  final Suspension suspension;
  final String? message;

  /// The chairman only
  final VoidCallback? onLift;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = suspensionColours(context);
    final by = suspension.byName;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.block_rounded, size: 20, color: c.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '"${suspension.reason}"${by == null ? '' : ' · $by (chairman)'}',
            style: textTheme.bodyMedium?.copyWith(color: c.ink),
          ),
          const SizedBox(height: 4),
          Text(
            [suspensionPeriod(suspension), ?message].join('. '),
            style: textTheme.bodySmall?.copyWith(color: c.ink),
          ),
          if (onLift != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onLift,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.ink,
                  side: BorderSide(color: c.ink),
                ),
                child: const Text('Lift suspension'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── C1: Suspend ─────────────────────────────────────────────────────────

typedef SuspendInput = ({String reason, DateTime? lastDay});

Future<SuspendInput?> showSuspendSheet(
  BuildContext context, {
  required String teamName,
}) {
  return showModalBottomSheet<SuspendInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SuspendSheet(teamName: teamName),
  );
}

class _SuspendSheet extends StatefulWidget {
  const _SuspendSheet({required this.teamName});

  final String teamName;

  @override
  State<_SuspendSheet> createState() => _SuspendSheetState();
}

class _SuspendSheetState extends State<_SuspendSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  /// False: until the chairman lifts it. True: on [_lastDay].
  bool _dated = false;
  DateTime? _lastDay;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      initialDate: _lastDay ?? today.add(const Duration(days: 14)),
      helpText: 'Last day of the suspension',
    );
    if (picked != null && mounted) {
      setState(() {
        _lastDay = picked;
        _dated = true;
      });
    }
  }

  void _suspend() {
    if (!_formKey.currentState!.validate()) return;
    if (_dated && _lastDay == null) {
      _pickDay();
      return;
    }
    Navigator.of(
      context,
    ).pop((reason: _reason.text.trim(), lastDay: _dated ? _lastDay : null));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final lastDay = _lastDay;

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
                'Suspend ${widget.teamName}?',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Chairman only. ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text:
                          "While suspended the team can't add or edit "
                          'players, edit its profile, or ask for changes. '
                          'Later: no team sheets. It stays approved.',
                    ),
                  ],
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason (the team sees it) *',
                  helperText: '10–500 characters.',
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Write at least 10 characters'
                    : null,
              ),
              const SizedBox(height: 14),
              const SectionTitle('Ends'),
              TileGroup(
                children: [
                  _EndChoice(
                    selected: !_dated,
                    title:
                        'When the chairman lifts it (after the FA board '
                        'meets the club)',
                    onTap: () => setState(() => _dated = false),
                  ),
                  _EndChoice(
                    selected: _dated,
                    title: lastDay == null
                        ? 'On a date'
                        : 'On a date: ${formatDate(lastDay)}',
                    subtitle: lastDay == null ? null : 'Tap to change the date',
                    onTap: _pickDay,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const OneLine(Text('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _suspend,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFC8283A)
                            : scheme.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const OneLine(Text('Suspend')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One "Ends" choice, drawn like a radio button.
class _EndChoice extends StatelessWidget {
  const _EndChoice({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
    );
  }
}

// ── C4: Lift ────────────────────────────────────────────────────────────

typedef LiftInput = ({LiftReason reason, String? note});

Future<LiftInput?> showLiftSheet(
  BuildContext context, {
  required String teamName,
}) {
  return showModalBottomSheet<LiftInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LiftSheet(teamName: teamName),
  );
}

class _LiftSheet extends StatefulWidget {
  const _LiftSheet({required this.teamName});

  final String teamName;

  @override
  State<_LiftSheet> createState() => _LiftSheetState();
}

class _LiftSheetState extends State<_LiftSheet> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  LiftReason? _reason;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _lift() {
    final reason = _reason;
    if (reason == null || !_formKey.currentState!.validate()) return;
    final note = _note.text.trim();
    Navigator.of(
      context,
    ).pop((reason: reason, note: note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final isOther = _reason == LiftReason.other;

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
                "Lift ${widget.teamName}'s suspension?",
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              const SectionTitle('Why'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in LiftReason.values)
                    ChoiceChip(
                      label: Text(reason.label),
                      selected: _reason == reason,
                      onSelected: (_) => setState(() => _reason = reason),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                inputFormatters: [LengthLimitingTextInputFormatter(300)],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: isOther ? 'Note *' : 'Note (optional)',
                  helperText: 'The team sees it, e.g. the receipt number.',
                  alignLabelWithHint: true,
                ),
                // "Other" needs a note (the rules too)
                validator: (value) => isOther && (value?.trim().length ?? 0) < 5
                    ? 'Say why (at least 5 characters)'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const OneLine(Text('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _reason == null ? null : _lift,
                      style: FilledButton.styleFrom(
                        backgroundColor: approveGreen(context),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const OneLine(Text('Lift suspension')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── History on the FA's team page (C5) ──────────────────────────────────

class SuspensionHistory extends ConsumerWidget {
  const SuspensionHistory({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(suspensionHistoryProvider(teamId)).value ?? const [];
    if (history.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    String ended(Suspension s) {
      final liftedAt = s.liftedAt;
      if (liftedAt != null) {
        final note = s.liftNote;
        return [
          'Lifted ${formatDayMonth(liftedAt)}: '
              '${s.liftReason?.label ?? 'lifted'}',
          if (note != null) '"$note"',
          ?s.liftedByName,
        ].join(' · ');
      }
      return s.isActive ? 'In force' : 'Ended';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        const SectionTitle('Suspensions'),
        TileGroup(
          children: [
            for (final s in history)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('"${s.reason}"', style: textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${suspensionPeriod(s)} · ${ended(s)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
