import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/open_link.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/dashed_border.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/payments/data/payment_repository.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/payments/presentation/widgets/payment_row.dart';

/// The FA's green.
({Color ink, Color bg, Color line}) _greens(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? (
            ink: const Color(0xFF7BE3B0),
            bg: const Color(0xFF123D2B),
            line: const Color(0xFF2E7D57),
          )
        : (
            ink: const Color(0xFF00502F),
            bg: const Color(0xFFE3F2EA),
            line: const Color(0xFF1E8E5A),
          );

/// Board R7: one club's season fee, for the FA. Each waiting payment has
/// the green tick ("Payment confirmed") and "Payment not found"; the FA
/// can also record cash it received.
class FaPaymentCard extends ConsumerWidget {
  const FaPaymentCard({
    super.key,
    required this.requestUid,
    required this.teamName,
    this.teamId,
    this.requestPending = false,
  });

  final String requestUid;
  final String teamName;
  final String? teamId;

  /// The registration is still waiting for the FA. A "not found" payment
  /// then sends it back to the club (when nothing is confirmed yet).
  final bool requestPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final greens = _greens(context);
    final summary = ref.watch(feeSummaryProvider(requestUid)).value ??
        const FeeSummary(confirmed: 0, fee: Season.fee);
    final paymentsAsync = ref.watch(clubPaymentsProvider(requestUid));
    final payments = paymentsAsync.value ?? const <Payment>[];
    final firstWaiting = payments.indexWhere((p) => p.isWaiting);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: summary.hasStarted ? greens.line : scheme.outline,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "GH₵ 500 of 1,000 confirmed      GH₵ 500 left"
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: cedis(summary.confirmed),
                    children: [
                      TextSpan(
                        text: ' of ${cedis(Season.fee).substring(4)} '
                            'confirmed',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                summary.isPaid ? 'Fully paid' : '${cedis(summary.left)} left',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: summary.isPaid ? greens.ink : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 8,
              color: greens.line,
              backgroundColor: scheme.outline.withValues(alpha: 0.4),
              semanticsLabel: 'Season fee paid',
              semanticsValue:
                  '${cedis(summary.confirmed)} of ${cedis(Season.fee)}',
            ),
          ),
          const SizedBox(height: 12),
          if (paymentsAsync.isLoading && payments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No payment sent yet.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          for (final (i, payment) in payments.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: payment.status == PaymentStatus.notFound
                  ? PaymentRow(payment: payment, divider: false)
                  : _PaymentBlock(
                      payment: payment,
                      // Board R7: the newest waiting payment gets
                      // [Payment not found] [+ Record cash] side by side
                      onRecordCash: i == firstWaiting
                          ? () => _recordCash(context, ref)
                          : null,
                      rejectsRequest: requestPending && !summary.hasStarted,
                    ),
            ),
          // Nothing waiting: Record cash on its own
          if (firstWaiting < 0)
            RecordCashButton(onPressed: () => _recordCash(context, ref)),
        ],
      ),
    );
  }

  /// Cash the FA received in person: confirmed straight away.
  Future<void> _recordCash(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({int amount, String note})>(
      context: context,
      builder: (_) => const _CashDialog(),
    );
    final faUid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (result == null || faUid == null || !context.mounted) return;

    try {
      final receipt = await ref.read(paymentRepositoryProvider).recordCash(
            requestUid: requestUid,
            teamId: teamId,
            teamName: teamName,
            amount: result.amount,
            note: result.note,
            faUid: faUid,
          );
      if (context.mounted) {
        AppToast.success(context, 'Cash recorded. Receipt $receipt.');
      }
    } catch (error) {
      if (context.mounted) AppToast.error(context, appErrorMessage(error));
    }
  }
}

/// One waiting or confirmed payment: its details, then the green tick.
class _PaymentBlock extends ConsumerStatefulWidget {
  const _PaymentBlock({
    required this.payment,
    this.onRecordCash,
    this.rejectsRequest = false,
  });

  final Payment payment;

  /// Set on the block that shows "+ Record cash" next to "Payment not
  /// found" (board R7).
  final VoidCallback? onRecordCash;

  /// "Not found" also sends the registration back to the club.
  final bool rejectsRequest;

  @override
  ConsumerState<_PaymentBlock> createState() => _PaymentBlockState();
}

class _PaymentBlockState extends ConsumerState<_PaymentBlock> {
  bool _busy = false;

  String? get _faUid => ref.read(authRepositoryProvider).currentUser?.uid;

  Future<void> _confirm() async {
    final payment = widget.payment;
    int? amount;
    if (payment.amount == null) {
      // "Already paid": the FA fills in the amount from its records
      amount = await showDialog<int>(
        context: context,
        builder: (_) => const _AmountDialog(),
      );
      if (amount == null) return;
    }
    final faUid = _faUid;
    if (faUid == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final receipt = await ref
          .read(paymentRepositoryProvider)
          .confirm(payment, faUid: faUid, amount: amount);
      if (mounted) {
        AppToast.success(context, 'Payment confirmed. Receipt $receipt.');
      }
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notFound() async {
    final reason = await showReasonSheet(
      context,
      title: 'Payment not found?',
      message: widget.rejectsRequest
          ? 'Use this only if the ID is not on the FA statement or the '
              'details are false. The registration goes back to the club '
              'with your reason, to correct and send again.'
          : 'Use this only if the ID is not on the FA statement or the '
              'details are false. The club sees your reason and can send '
              'it again.',
      fieldLabel: 'Reason for the club',
      quickReasons: const [
        'ID not on our statement',
        'The amount on the statement is different',
        'No record of this cash payment',
      ],
    );
    final faUid = _faUid;
    if (reason == null || faUid == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(paymentRepositoryProvider).markNotFound(
            widget.payment,
            faUid: faUid,
            reason: reason,
            rejectRequest: widget.rejectsRequest,
          );
      if (mounted) {
        AppToast.success(
          context,
          widget.rejectsRequest
              ? 'Marked as not found. The registration went back to the club.'
              : 'Marked as not found.',
        );
      }
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The pencil on cash the FA recorded: fix a typing mistake.
  Future<void> _correct() async {
    final payment = widget.payment;
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _AmountDialog(
        title: 'Correct the amount',
        message: 'The receipt number (${payment.receiptNo ?? ''}) stays the '
            "same. The club's total changes by the difference.",
        initial: payment.amount,
        action: 'Save',
      ),
    );
    final faUid = _faUid;
    if (amount == null || amount == payment.amount || faUid == null ||
        !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(paymentRepositoryProvider)
          .correctCashAmount(payment, amount: amount, faUid: faUid);
      if (mounted) AppToast.success(context, 'Amount corrected.');
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final link = isDark ? const Color(0xFF7DBBFA) : scheme.primary;
    final greens = _greens(context);
    final payment = widget.payment;
    final canCorrect = payment.recordedByFa && payment.isConfirmed;
    final confirmed = payment.isConfirmed;
    final amount = payment.amount;
    final paidOn = payment.paidOn;
    final proof = payment.proofUrl;

    Widget line(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 13.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              value,
            ],
          ),
        );
    Text bold(String text) => Text(
          text,
          style: textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              line('Method', bold(payment.method.label)),
              if (payment.reference case final reference?)
                line(
                  'Transaction ID',
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: reference));
                      if (context.mounted) {
                        AppToast.success(context, 'ID copied.');
                      }
                    },
                    child: bold(reference),
                  ),
                ),
              line(
                'Amount, date',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    bold([
                      amount == null ? 'From FA records' : cedis(amount),
                      if (paidOn != null) formatDate(paidOn),
                      ?payment.paidWhen,
                    ].join(', ')),
                    if (canCorrect)
                      IconButton(
                        onPressed: _busy ? null : _correct,
                        tooltip: 'Correct the amount',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: link,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              if (payment.paidTo case final to?) line('Paid to', bold(to)),
              if (proof != null)
                line(
                  'Proof',
                  InkWell(
                    // openLink straight from the tap (iPhone Safari)
                    onTap: () => openLink(proof),
                    child: Text(
                      'View screenshot',
                      style: TextStyle(
                        color: link,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (payment.recordedByFa)
                line(
                  'Recorded',
                  bold(payment.editedAt == null
                      ? 'By the FA'
                      : 'By the FA · amount corrected'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // The green tick
        Semantics(
          checked: confirmed,
          button: !confirmed,
          child: Material(
            color: confirmed ? greens.bg : scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: greens.line, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: confirmed || _busy ? null : _confirm,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: greens.line, width: 2),
                      ),
                      child: _busy
                          ? Padding(
                              padding: const EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: greens.line,
                              ),
                            )
                          : confirmed
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: greens.line,
                                )
                              : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment confirmed',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: greens.ink,
                            ),
                          ),
                          Text(
                            confirmed
                                ? [
                                    if (payment.reviewedAt case final at?)
                                      formatDateTime(at),
                                    'receipt ${payment.receiptNo ?? ''}',
                                  ].join(' · ')
                                : "Check it against the FA's MoMo statement "
                                    'or list, then tick.',
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!confirmed) ...[
          const SizedBox(height: 8),
          // Board R7: [Payment not found] [+ Record cash], then the note
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _notFound,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Payment not found'),
                ),
              ),
              if (widget.onRecordCash case final onRecordCash?) ...[
                const SizedBox(width: 8),
                Expanded(child: RecordCashButton(onPressed: onRecordCash)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              'Use "Payment not found" only if the ID isn\'t on the FA\'s '
                  'statement or the details are false.',
              widget.rejectsRequest
                  ? 'The registration goes back to the club with your reason.'
                  : 'The club sees your reason and can send it again.',
              if (widget.onRecordCash != null)
                '"Record cash" is for money the FA received in person.',
            ].join(' '),
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// "+ Record cash": dashed, for money the FA received in person
/// (board R7).
class RecordCashButton extends StatelessWidget {
  const RecordCashButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final link = isDark ? const Color(0xFF7DBBFA) : scheme.primary;

    return DashedBorder(
      color: scheme.outline,
      radius: 12,
      strokeWidth: 1,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: link,
          minimumSize: const Size.fromHeight(40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        child: const Text('+ Record cash'),
      ),
    );
  }
}

/// "How much did they pay?" for an "already paid" payment, or the
/// corrected amount of recorded cash.
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    this.title = 'Confirm this payment',
    this.message = 'The club paid before the app. Enter the amount from the '
        "FA's records.",
    this.initial,
    this.action = 'Confirm',
  });

  final String title;
  final String message;
  final int? initial;
  final String action;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount =
      TextEditingController(text: widget.initial?.toString() ?? '');

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Amount (GH₵)'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              validator: _validAmount,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(int.parse(_amount.text.trim()));
          },
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// "Record cash": amount and an optional note.
class _CashDialog extends StatefulWidget {
  const _CashDialog();

  @override
  State<_CashDialog> createState() => _CashDialogState();
}

class _CashDialogState extends State<_CashDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record cash'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cash the FA received in person. It is confirmed straight '
              'away, with a receipt number.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Amount (GH₵)'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              validator: _validAmount,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'When (optional)',
                hintText: 'e.g. at the meeting, 2 Nov',
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop((
              amount: int.parse(_amount.text.trim()),
              note: _note.text,
            ));
          },
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          child: const Text('Record'),
        ),
      ],
    );
  }
}

String? _validAmount(String? value) {
  final amount = int.tryParse(value?.trim() ?? '');
  if (amount == null || amount < 1) return 'Enter the amount';
  if (amount > Season.fee) return 'Up to ${cedis(Season.fee)}';
  return null;
}
