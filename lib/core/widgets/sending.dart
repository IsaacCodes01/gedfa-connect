import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/widgets/loading.dart';

/// M2: the shared look for "the app is SAVING something you did".
/// The words say the action: "Saving…", "Sending to GEDFA…", "Suspending…".
/// Loading things to read is M1, in `loading.dart`.

/// The line under a busy button when a save passes [slowAfter].
const slowSendingText = 'Still sending, your connection seems slow.';

enum _BusyKind { filled, outlined }

/// S1: a save button that shows what it is doing. While [busy] it keeps its
/// size and colour, shows a spinner and [busyLabel], and ignores taps; after
/// 8 seconds a slow note shows under it.
///
/// ```dart
/// BusyButton(
///   label: 'Suspend player',
///   busyLabel: 'Suspending…',
///   busy: _busy,
///   onPressed: _canSave ? _save : null,
/// )
/// ```
///
/// Like the theme's buttons it is full-width; in a `Row` (not in `Expanded`)
/// pass a [style] with `minimumSize: const Size(0, 40)`.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
    this.icon,
    this.style,
    this.showSlowNote = true,
  }) : _kind = _BusyKind.filled;

  const BusyButton.outlined({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
    this.icon,
    this.style,
    this.showSlowNote = true,
  }) : _kind = _BusyKind.outlined;

  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonStyle? style;

  /// Off for small buttons in a row, where a line underneath would not fit.
  final bool showSlowNote;
  final _BusyKind _kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filled = _kind == _BusyKind.filled;
    final spinnerColor = filled ? scheme.onPrimary : scheme.primary;

    final Widget content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: busy
          ? Row(
              key: const ValueKey('busy'),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: spinnerColor,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(busyLabel, overflow: TextOverflow.ellipsis),
                ),
              ],
            )
          : Row(
              key: const ValueKey('idle'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    // While busy the button keeps an onPressed (so it keeps its colour) but
    // taps are ignored, so a save is never sent twice.
    final VoidCallback? press = busy ? () {} : onPressed;
    final Widget button = IgnorePointer(
      ignoring: busy,
      child: filled
          ? FilledButton(onPressed: press, style: style, child: content)
          : OutlinedButton(onPressed: press, style: style, child: content),
    );

    if (!busy || !showSlowNote) return button;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        button,
        SlowNote(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              slowSendingText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// S1: greys and locks a form while it is being saved, so nothing is
/// changed or tapped twice.
class FormLock extends StatelessWidget {
  const FormLock({super.key, required this.busy, required this.child});

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: busy,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: busy ? 0.5 : 1,
        child: child,
      ),
    );
  }
}

/// How far a long save has got ("Match 21 of 36").
class SendingProgress {
  const SendingProgress(this.done, this.total, {this.line});

  final int done;
  final int total;

  /// Words under the title; defaults to "[done] of [total]".
  final String? line;
}

/// S2: a long save in several parts (publish a season, postpone a league,
/// rename matches). [start] is where a stopped one carries on from. A sheet
/// covers the screen with a progress bar and
/// "Don't close the app" until [task] ends; its result (or error) comes back.
///
/// ```dart
/// final ok = await SendingSheet.run(
///   context,
///   title: 'Publishing the season…',
///   unit: 'Match',
///   task: (progress) => repo.publish(onProgress: progress),
/// );
/// ```
class SendingSheet extends StatefulWidget {
  const SendingSheet._({
    required this.title,
    required this.unit,
    required this.progress,
  });

  final String title;
  final String? unit;
  final ValueNotifier<SendingProgress?> progress;

  static Future<T> run<T>(
    BuildContext context, {
    required String title,
    String? unit,
    SendingProgress? start,
    required Future<T> Function(void Function(int done, int total) progress)
    task,
  }) async {
    final progress = ValueNotifier<SendingProgress?>(start);
    final navigator = Navigator.of(context, rootNavigator: true);
    var open = true;

    final closed = showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      barrierColor: const Color(0x8C081220),
      builder: (_) =>
          SendingSheet._(title: title, unit: unit, progress: progress),
    ).whenComplete(() => open = false);

    try {
      return await task((done, total) {
        progress.value = SendingProgress(done, total);
      });
    } finally {
      if (open) navigator.pop();
      await closed;
      progress.dispose();
    }
  }

  @override
  State<SendingSheet> createState() => _SendingSheetState();
}

class _SendingSheetState extends State<SendingSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: ValueListenableBuilder<SendingProgress?>(
            valueListenable: widget.progress,
            builder: (context, p, _) {
              final fraction = p == null || p.total == 0
                  ? null
                  : (p.done / p.total).clamp(0.0, 1.0);
              final line =
                  p?.line ??
                  (p == null
                      ? null
                      : widget.unit == null
                      ? '${p.done} of ${p.total}'
                      : '${widget.unit} ${p.done} of ${p.total}');

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SendIcon(),
                  const SizedBox(height: 14),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (line != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: fraction ?? 0),
                      duration: const Duration(milliseconds: 400),
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: fraction == null ? null : v,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _DontClose(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SendIcon extends StatelessWidget {
  const _SendIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox.square(
      dimension: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox.square(
            dimension: 58,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFFCD116),
            ),
          ),
          CircleAvatar(
            radius: 25,
            backgroundColor: scheme.surfaceContainerHighest,
            child: Icon(Icons.send_rounded, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _DontClose extends StatelessWidget {
  const _DontClose();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF3A3110) : const Color(0xFFFFF4C2);
    final fg = dark ? const Color(0xFFFCD116) : const Color(0xFF8A6A00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Don't close the app. If it stops, Try again carries on "
              'where it stopped.',
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
