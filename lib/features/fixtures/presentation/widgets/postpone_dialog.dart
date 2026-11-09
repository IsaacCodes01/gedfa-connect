import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/fixtures/domain/postpone_plan.dart';

/// What the FA chose: the new first day, and why (the clubs see it).
typedef PostponeChoice = ({DateTime newDay, String reason});

/// "Postpone …?" (3.0c1c, mockups C10, C11): the new date for [fieldLabel]
/// ("Starts", "Matchday 1"), how much later that is and where the end
/// ([lastWhat], "The last matchday") moves to, and why. Null if cancelled.
Future<PostponeChoice?> showPostponeDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String fieldLabel,
  required DateTime from,
  required DateTime lastFrom,
  required String lastWhat,
}) {
  return showDialog<PostponeChoice>(
    context: context,
    builder: (_) => _PostponeDialog(
      title: title,
      message: message,
      fieldLabel: fieldLabel,
      from: from,
      lastFrom: lastFrom,
      lastWhat: lastWhat,
    ),
  );
}

class _PostponeDialog extends StatefulWidget {
  const _PostponeDialog({
    required this.title,
    required this.message,
    required this.fieldLabel,
    required this.from,
    required this.lastFrom,
    required this.lastWhat,
  });

  final String title;
  final String message;
  final String fieldLabel;
  final DateTime from;
  final DateTime lastFrom;
  final String lastWhat;

  @override
  State<_PostponeDialog> createState() => _PostponeDialogState();
}

class _PostponeDialogState extends State<_PostponeDialog> {
  final _reason = TextEditingController();
  DateTime? _newDay;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final dayAfter = shiftDays(widget.from, 1);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final first = dayAfter.isAfter(tomorrow) ? dayAfter : tomorrow;
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDay ?? shiftDays(first, 6),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: shiftDays(widget.from, 365),
      helpText: widget.fieldLabel,
    );
    if (picked != null && mounted) setState(() => _newDay = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newDay = _newDay;
    final days = newDay == null ? 0 : daysBetween(widget.from, newDay);
    final lastMoves = daysBetween(widget.from, widget.lastFrom) > 0;
    final reason = _reason.text.trim();
    final PostponeChoice? choice = newDay != null && reason.length >= 3
        ? (newDay: newDay, reason: reason)
        : null;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.message,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pick,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.fieldLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${formatShortDate(widget.from)} → '),
                      if (newDay != null)
                        TextSpan(
                          text: formatShortDate(newDay),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )
                      else
                        TextSpan(
                          text: 'Pick the new date',
                          style: TextStyle(color: scheme.primary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (newDay != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AccentTone.gold.background(isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  [
                    '${laterLabel(days)}.',
                    if (lastMoves)
                      '${widget.lastWhat} moves from '
                          '${formatShortDate(widget.lastFrom)} to '
                          '${formatShortDate(shiftDays(widget.lastFrom, days))}.',
                  ].join(' '),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AccentTone.gold.foreground(isDark),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Why (the clubs see it)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: choice == null
              ? null
              : () => Navigator.pop(context, choice),
          child: const Text('Postpone'),
        ),
      ],
    );
  }
}
