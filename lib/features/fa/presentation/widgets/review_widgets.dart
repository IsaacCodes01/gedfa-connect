import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pieces shared by the FA review screens (team requests and players):
/// check lines, detail rows, the Reject / Approve bar and the reason sheet.

/// The FA's "approve" green (a bit lighter in dark mode).
Color approveGreen(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E8E5A)
        : const Color(0xFF006B3F);

// ── Check line ───────────────────────────────────────────────────────────

/// One automatic check: green tick, red warning or hourglass (checking).
class CheckLine extends StatelessWidget {
  const CheckLine({
    super.key,
    required this.ok,
    required this.okText,
    this.badText = '',
    this.waitingText = '',
  });

  /// true = passed, false = failed, null = still checking
  final bool? ok;
  final String okText;
  final String badText;
  final String waitingText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final green = isDark ? const Color(0xFF7BE3B0) : const Color(0xFF006B3F);

    final (icon, color, text) = switch (ok) {
      true => (Icons.check_circle_rounded, green, okText),
      false => (Icons.warning_amber_rounded, scheme.error, badText),
      null => (
          Icons.hourglass_empty_rounded,
          scheme.onSurfaceVariant,
          waitingText
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ── Detail row ───────────────────────────────────────────────────────────

/// "Label    Value" inside a TileGroup. A null value shows "Not given".
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final value = this.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not given',
              style: value == null
                  ? textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    )
                  : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reject / Approve bar ─────────────────────────────────────────────────

/// The bar at the bottom of a review screen: Reject (outlined red) and
/// Approve (filled green, twice as wide). Shows a spinner while [busy].
class ReviewActionsBar extends StatelessWidget {
  const ReviewActionsBar({
    super.key,
    required this.approveLabel,
    required this.busy,
    required this.onReject,
    required this.onApprove,
    this.blockedText,
  });

  final String approveLabel;
  final bool busy;
  final VoidCallback onReject;

  /// Null greys out Approve (e.g. no payment confirmed yet).
  final VoidCallback? onApprove;

  /// Red line above the buttons saying why Approve is greyed out.
  final String? blockedText;

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
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (blockedText case final text?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(color: scheme.error, width: 1.5),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: busy ? null : onApprove,
                          style: FilledButton.styleFrom(
                            backgroundColor: approveGreen(context),
                            foregroundColor: Colors.white,
                            // Greyed out = the same green, faded
                            disabledBackgroundColor:
                                approveGreen(context).withValues(alpha: 0.45),
                            disabledForegroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          icon: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(approveLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reason sheet ─────────────────────────────────────────────────────────

/// Opens the reject sheet and returns the reason, or null if cancelled.
///
/// [quickReasons] are chips: tapping one adds it to the text box.
Future<String?> showReasonSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String fieldLabel,
  required List<String> quickReasons,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true, // lets the sheet move up with the keyboard
    showDragHandle: true,
    builder: (_) => ReasonSheet(
      title: title,
      message: message,
      fieldLabel: fieldLabel,
      quickReasons: quickReasons,
    ),
  );
}

class ReasonSheet extends StatefulWidget {
  const ReasonSheet({
    super.key,
    required this.title,
    required this.message,
    required this.fieldLabel,
    required this.quickReasons,
  });

  final String title;
  final String message;
  final String fieldLabel;
  final List<String> quickReasons;

  @override
  State<ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<ReasonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _picked = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Tapping a quick reason adds it to (or removes it from) the text box.
  void _toggle(String reason) {
    setState(() {
      if (!_picked.remove(reason)) _picked.add(reason);
      _controller.text = _picked.isEmpty
          ? ''
          : '${_picked.join('. ')}. Please correct and resubmit.';
    });
  }

  void _send() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      // Keeps the text box above the keyboard
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + keyboard),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                widget.message,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Text(
                'QUICK REASONS',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in widget.quickReasons)
                    FilterChip(
                      label: Text(reason),
                      selected: _picked.contains(reason),
                      onSelected: (_) => _toggle(reason),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _controller,
                minLines: 3,
                maxLines: 5,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: widget.fieldLabel,
                  helperText: 'At least 10 characters. Be specific so they '
                      'know what to correct.',
                  helperMaxLines: 2,
                  alignLabelWithHint: true,
                ),
                // Same limits as the security rules (10 to 500)
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Write at least 10 characters'
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
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _send,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFC8283A)
                                : scheme.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Send rejection'),
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

// ── Dialog bullet ────────────────────────────────────────────────────────

/// "•  text" line used inside the approve dialogs.
class DialogBullet extends StatelessWidget {
  const DialogBullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
