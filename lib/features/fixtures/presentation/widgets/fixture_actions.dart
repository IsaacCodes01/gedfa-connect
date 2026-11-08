import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:go_router/go_router.dart';

/// FA: what can be done with a match (tapping it in the Fixtures tab):
/// change it, see its kits, postpone it or set its new date, cancel it.
Future<void> showFixtureActions(
  BuildContext context,
  WidgetRef ref,
  Fixture f,
) {
  final scheme = Theme.of(context).colorScheme;

  Widget item(IconData icon, String title, String detail, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      subtitle: Text(detail),
      onTap: onTap,
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '${f.home.name} v ${f.away.name}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            if (f.isCancelled)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Cancelled. A cancelled match can no longer be changed.'
                  '${(f.note ?? '').isEmpty ? '' : ' Reason: ${f.note}'}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            if (!f.isCancelled && f.kickoffAt != null)
              item(Icons.edit_calendar_outlined, 'Change the match',
                  'Teams, date, time, venue, matchday', () {
                Navigator.pop(sheet);
                context.push(Routes.adminEditFixture(f.id));
              }),
            item(Icons.checkroom_outlined, 'Kits for this match',
                'What each team and goalkeeper wears', () {
              Navigator.pop(sheet);
              context.push(Routes.adminFixtureKits(f.id));
            }),
            if (f.isScheduled)
              item(Icons.pause_circle_outline, 'Postpone',
                  'With a reason; the new date now or later', () {
                Navigator.pop(sheet);
                showPostponeSheet(context, ref, f);
              }),
            if (f.isPostponed)
              item(Icons.event_available_outlined, 'Set the new date',
                  'Both teams are told', () {
                Navigator.pop(sheet);
                showPostponeSheet(context, ref, f, newDateOnly: true);
              }),
            if (!f.isCancelled)
              item(Icons.cancel_outlined, 'Cancel the match', 'With a reason',
                  () {
                Navigator.pop(sheet);
                _cancel(context, ref, f);
              }, color: scheme.error),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Postpone (E2), or [newDateOnly]: give a postponed match its new date.
Future<void> showPostponeSheet(
  BuildContext context,
  WidgetRef ref,
  Fixture f, {
  bool newDateOnly = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PostponeSheet(fixture: f, newDateOnly: newDateOnly),
  );
}

class _PostponeSheet extends ConsumerStatefulWidget {
  const _PostponeSheet({required this.fixture, required this.newDateOnly});

  final Fixture fixture;
  final bool newDateOnly;

  @override
  ConsumerState<_PostponeSheet> createState() => _PostponeSheetState();
}

class _PostponeSheetState extends ConsumerState<_PostponeSheet> {
  final _reason = TextEditingController();
  late bool _dateNow = widget.newDateOnly;
  DateTime? _date;
  late TimeOfDay _time = widget.fixture.kickoffAt == null
      ? const TimeOfDay(hour: 15, minute: 0)
      : TimeOfDay.fromDateTime(widget.fixture.kickoffAt!.toLocal());
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime? get _kickoff {
    final d = _date;
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, _time.hour, _time.minute);
  }

  String? get _problem {
    if (!widget.newDateOnly && _reason.text.trim().length < 3) {
      return 'Write the reason (teams read it)';
    }
    if (_dateNow) {
      final k = _kickoff;
      if (k == null) return 'Pick the new date';
      if (!k.isAfter(DateTime.now())) return 'Pick a time in the future';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today.add(const Duration(days: 3)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'New date',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Kick-off',
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final problem = _problem;
    final me = ref.read(authRepositoryProvider).currentUser;
    if (problem != null || me == null) {
      AppToast.warning(context, problem ?? 'Please sign in again.');
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(fixtureRepositoryProvider);
    try {
      if (widget.newDateOnly) {
        await repo.setNewDate(widget.fixture, kickoff: _kickoff!, by: me);
      } else {
        await repo.postpone(
          widget.fixture,
          reason: _reason.text,
          newKickoff: _dateNow ? _kickoff : null,
          by: me,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(
        context,
        widget.newDateOnly
            ? 'New date saved. Both teams were told.'
            : 'Match postponed. Both teams were told.',
      );
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    final scheme = Theme.of(context).colorScheme;
    final kickoff = _kickoff;
    final due = kickoff?.subtract(Fixture.sheetLead);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.newDateOnly ? 'New date' : 'Postpone'}: '
              '${f.home.name} v ${f.away.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            if (!widget.newDateOnly) ...[
              TextField(
                controller: _reason,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason (teams see this)',
                  hintText: 'e.g. Pitch waterlogged',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('New date now')),
                  ButtonSegment(value: false, label: Text('Not fixed yet')),
                ],
                selected: {_dateNow},
                onSelectionChanged: (v) => setState(() => _dateNow = v.first),
              ),
              const SizedBox(height: 12),
            ],
            if (_dateNow) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_date == null
                          ? 'New date'
                          : formatShortDate(_date!)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_time.format(context)),
                    ),
                  ),
                ],
              ),
              if (due != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Team sheets move with it: now due '
                  '${formatShortDate(due)}, ${formatTime(due)}.',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ] else
              Text(
                'The match shows "Postponed" until you set the new date '
                '(tap the match, then Set the new date).',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(widget.newDateOnly
                  ? 'Save and tell both teams'
                  : 'Postpone and tell both teams'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _cancel(BuildContext context, WidgetRef ref, Fixture f) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => _CancelDialog(fixture: f),
  );
  final me = ref.read(authRepositoryProvider).currentUser;
  if (reason == null || me == null || !context.mounted) return;
  try {
    await ref.read(fixtureRepositoryProvider).cancel(f, reason: reason, by: me);
    if (context.mounted) {
      AppToast.success(context, 'Match cancelled. Both teams were told.');
    }
  } catch (error) {
    if (context.mounted) AppToast.error(context, appErrorMessage(error));
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.fixture});

  final Fixture fixture;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _reason.text.trim().length >= 3;
    return AlertDialog(
      title: const Text('Cancel this match?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.fixture.home.name} v ${widget.fixture.away.name}. '
            "It can't be changed again after this; both teams are told.",
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 200,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reason (teams see this)',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep it'),
        ),
        TextButton(
          onPressed: ok ? () => Navigator.pop(context, _reason.text) : null,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Cancel the match'),
        ),
      ],
    );
  }
}
