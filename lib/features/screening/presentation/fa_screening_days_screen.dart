import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';
import 'package:gedfa_connect/features/screening/domain/screening_day.dart';
import 'package:gedfa_connect/features/screening/presentation/widgets/screening_countdown.dart';
import 'package:go_router/go_router.dart';

const _monthCaps = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// FA › More › Juvenile screening (2.14b, board J3).
///
/// Top: the coming screening days, each with how many children wait in
/// its age groups across the district. Below: a form to add a day.
/// "Save and announce" saves the day AND publishes an announcement to
/// Juvenile teams, which also puts the blue card on their Squad tab.
class FaScreeningDaysScreen extends ConsumerStatefulWidget {
  const FaScreeningDaysScreen({super.key, this.fromHome = false});

  /// Opened from a "Needs you" row on Home: back arrow to Home (2.12a)
  final bool fromHome;

  @override
  ConsumerState<FaScreeningDaysScreen> createState() =>
      _FaScreeningDaysScreenState();
}

class _FaScreeningDaysScreenState
    extends ConsumerState<FaScreeningDaysScreen> {
  final _venue = TextEditingController();
  final _note = TextEditingController();
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final _groups = <AgeGroup>{};
  bool _showErrors = false;
  bool _busy = false;

  /// Redraws every 30 seconds, so "Start screening" switches on by
  /// itself at the start time.
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _venue.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime? get _startsAt {
    final date = _date;
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day, _time.hour, _time.minute);
  }

  // ---------- Pickers ----------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Screening date',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Start time',
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  // ---------- Save / cancel ----------

  String? get _problem {
    final startsAt = _startsAt;
    if (startsAt == null) return 'Pick the date';
    if (!startsAt.isAfter(DateTime.now())) return 'Pick a time in the future';
    if (_venue.text.trim().length < 2) return 'Enter the venue';
    if (_groups.isEmpty) return 'Choose at least one age group';
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    final problem = _problem;
    final me = ref.read(authRepositoryProvider).currentUser;
    if (problem != null || me == null) {
      AppToast.warning(context, problem ?? 'Please sign in again.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(screeningRepositoryProvider).create(
            startsAt: _startsAt!,
            venue: _venue.text,
            groups: _groups.toList(),
            note: _note.text,
            by: me,
          );
      if (!mounted) return;
      AppToast.success(
        context,
        'Screening day saved and announced to Juvenile teams.',
      );
      setState(() {
        _date = null;
        _time = const TimeOfDay(hour: 9, minute: 0);
        _groups.clear();
        _venue.clear();
        _note.clear();
        _showErrors = false;
      });
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(ScreeningDay day) async {
    // null = "Keep it"; otherwise the reason (may be empty)
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(day: day),
    );
    final me = ref.read(authRepositoryProvider).currentUser;
    if (reason == null || me == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(screeningRepositoryProvider)
          .cancel(day, reason: reason, by: me);
      if (mounted) AppToast.success(context, 'Screening day cancelled.');
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(upcomingScreeningsProvider);
    final children = ref.watch(juvenilePlayersProvider).value ?? const [];

    int waitingFor(ScreeningDay day) => children
        .where((p) =>
            p.isWaitingForScreening && day.groups.contains(p.ageGroup))
        .length;

    // Back goes to More, or to Home when opened from Home (2.12a)
    final back = widget.fromHome ? Routes.adminHome : Routes.adminMore;

    return PopScope(
      canPop: !_busy && !widget.fromHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) context.go(back);
      },
      child: Scaffold(
        appBar: GedfaAppBar(
          title: 'Juvenile screening',
          subtitle: 'District FA · More',
          leading: BackButton(onPressed: () => context.go(back)),
        ),
        bottomNavigationBar: _SaveBar(busy: _busy, onSave: _save),
        body: daysAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: appErrorMessage(error),
            onRetry: () => ref.invalidate(upcomingScreeningsProvider),
          ),
          data: (days) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Heading('Coming up'),
                    _ComingUp(
                      days: days,
                      waitingFor: waitingFor,
                      enabled: !_busy,
                      onCancel: _cancel,
                      // Board J4: one child after another (2.14c)
                      onStart: (day) =>
                          context.goKeepingHome(Routes.adminScreeningDay(day.id)),
                      // The countdown reached 0: show Start screening
                      onStarted: () {
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    const _Heading('Add a screening day'),
                    _form(),
                    const SizedBox(height: 14),
                    const _InfoBox(
                      'Saving publishes an announcement to Juvenile teams '
                      '(and a phone alert once push is ready). The blue card '
                      'on their Squad tab disappears the day after.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final date = _date;
    final timeText = MaterialLocalizations.of(context)
        .formatTimeOfDay(_time, alwaysUse24HourFormat: false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PickerField(
                  label: 'Date *',
                  value: date == null
                      ? ''
                      : '${ScreeningDay.dateTextFor(date)} ${date.year}',
                  hint: 'Pick a date',
                  icon: Icons.calendar_month_outlined,
                  errorText:
                      _showErrors && date == null ? 'Pick the date' : null,
                  enabled: !_busy,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerField(
                  label: 'Time *',
                  value: timeText,
                  hint: '',
                  icon: Icons.schedule_rounded,
                  enabled: !_busy,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _venue,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Venue *',
              hintText: 'e.g. Fetteh Park',
              errorText: _showErrors && _venue.text.trim().length < 2
                  ? 'Enter the venue'
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Age groups *',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final group in AgeGroup.values) ...[
                if (group != AgeGroup.values.first) const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: Center(child: Text(group.label)),
                    selected: _groups.contains(group),
                    showCheckmark: false,
                    onSelected: _busy
                        ? null
                        : (on) => setState(() {
                              if (on) {
                                _groups.add(group);
                              } else {
                                _groups.remove(group);
                              }
                            }),
                  ),
                ),
              ],
            ],
          ),
          if (_showErrors && _groups.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Choose at least one age group',
                style: textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            enabled: !_busy,
            maxLines: 2,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            decoration: const InputDecoration(
              labelText: 'What to bring (optional)',
              hintText: 'e.g. Birth certificate and a parent or guardian',
              helperText: 'Left empty, the announcement says nothing about it',
            ),
          ),
        ],
      ),
    );
  }
}

/// "Cancel Sat 14 Nov?" with an optional reason that goes into the
/// cancellation announcement. Pops the reason ('' if none), or null.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.day});

  final ScreeningDay day;

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
    final day = widget.day;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('Cancel ${day.dateText}?'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The ${day.groupsText} screening at ${day.venue} is removed '
              'and Juvenile teams get an announcement that it is cancelled.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              autofocus: true,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. The park is booked for a funeral',
                helperText: 'Shown to the teams in the announcement',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep it'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: const Text('Cancel the day'),
        ),
      ],
    );
  }
}

/// "COMING UP" and the list of days (or "No screening days yet").
class _ComingUp extends StatelessWidget {
  const _ComingUp({
    required this.days,
    required this.waitingFor,
    required this.enabled,
    required this.onCancel,
    required this.onStart,
    required this.onStarted,
  });

  final List<ScreeningDay> days;
  final int Function(ScreeningDay) waitingFor;
  final bool enabled;
  final ValueChanged<ScreeningDay> onCancel;
  final ValueChanged<ScreeningDay> onStart;
  final VoidCallback onStarted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final okBg = isDark ? const Color(0xFF123D2B) : const Color(0xFFE3F2EA);
    final okInk = isDark ? const Color(0xFF7BE3B0) : const Color(0xFF00502F);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline),
      ),
      child: days.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No screening days yet. Add one below; Juvenile teams are '
                'told straight away.',
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          : Column(
              children: [
                for (final day in days) ...[
                  if (day != days.first)
                    Divider(height: 1, color: scheme.outline),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        _DateTile(day: day.startsAt.toLocal()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${day.venue} · ${day.timeText}',
                                style: textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${day.groupsText} · ${waitingFor(day)} '
                                '${waitingFor(day) == 1 ? 'child' : 'children'}'
                                ' waiting',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: okBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'ANNOUNCED',
                            style: TextStyle(
                              color: okInk,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cancel this day',
                          onPressed: enabled ? () => onCancel(day) : null,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(60, 8, 0, 12),
                    // Board J3: a countdown from the moment the day is
                    // saved, then Start screening at the start time
                    child: day.hasStarted(DateTime.now())
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.tonalIcon(
                              onPressed: enabled ? () => onStart(day) : null,
                              icon: const Icon(
                                Icons.fact_check_outlined,
                                size: 18,
                              ),
                              label: Text(
                                waitingFor(day) == 0
                                    ? 'Open screening'
                                    : 'Start screening',
                              ),
                            ),
                          )
                        : _CountdownBox(day: day, onStarted: onStarted),
                  ),
                ],
              ],
            ),
    );
  }
}

/// "⏱ Opens in 2 h 14 min / Start screening appears here at 9:00 am"
class _CountdownBox extends StatelessWidget {
  const _CountdownBox({required this.day, required this.onStarted});

  final ScreeningDay day;
  final VoidCallback onStarted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA);
    final ink = isDark ? const Color(0xFFCFE4FB) : const Color(0xFF0B3F7A);
    final today = DateUtils.isSameDay(day.startsAt.toLocal(), DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 20, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreeningCountdown(
                  key: ValueKey(day.id),
                  startsAt: day.startsAt,
                  onStarted: onStarted,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: ink),
                ),
                Text(
                  today
                      ? 'Start screening appears here at ${day.timeText}'
                      : '${day.dateText} at ${day.timeText}',
                  style: textTheme.bodySmall?.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small calendar tile: "NOV" over "14".
class _DateTile extends StatelessWidget {
  const _DateTile({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: Container(
        width: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: scheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _monthCaps[day.month - 1],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${day.day}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only field that opens a picker (date or time).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          enabled: enabled,
          suffixIcon: Icon(icon),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// "Save and announce" at the bottom.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.busy, required this.onSave});

  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          // Not ResponsiveCenter: a plain Center grows as TALL as it may,
          // and a bottom bar may be as tall as the screen. heightFactor: 1
          // makes it only as tall as the button.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FilledButton.icon(
                onPressed: busy ? null : onSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.campaign_outlined),
                label: const Text('Save and announce'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
