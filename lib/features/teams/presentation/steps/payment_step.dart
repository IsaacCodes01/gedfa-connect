import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/files/picked_document.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/payments/presentation/widgets/payment_row.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/choice_card.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/file_upload_row.dart';
import 'package:image_picker/image_picker.dart';

/// "Date paid": a calendar up to today (the last year or so).
Future<DateTime?> pickPaymentDate(BuildContext context, DateTime? initial) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 1),
    lastDate: now,
    helpText: 'Date paid',
  );
}

/// "Proof (optional)": a screenshot of the payment message, under 1 MB.
Future<PickedDocument?> pickPaymentProof(BuildContext context) async {
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 1024 * 1024) {
      if (context.mounted) {
        AppToast.error(context, 'That image is too large. Choose a smaller one.');
      }
      return null;
    }
    return PickedDocument(bytes: bytes, name: file.name, isPdf: false);
  } catch (_) {
    if (context.mounted) {
      AppToast.error(context, "Couldn't open that image. Try another one.");
    }
    return null;
  }
}

/// Amount: whole cedis, 1 to the season fee.
String? validateAmount(String? value) {
  final amount = int.tryParse(value?.trim() ?? '');
  if (amount == null || amount < 1) return 'Enter the amount';
  if (amount > Season.fee) return 'Up to ${cedis(Season.fee)}';
  return null;
}

/// Step 6 (board R6): the season fee. GH₵ 1,000, paid to GEDFA's MoMo,
/// in parts if needed. The FA confirms every payment.
class PaymentStep extends StatelessWidget {
  const PaymentStep({
    super.key,
    required this.formKey,
    required this.showErrors,
    required this.enabled,
    required this.method,
    required this.onMethodChanged,
    required this.reference,
    required this.amount,
    required this.paidOn,
    required this.onPickDate,
    required this.paidWhen,
    required this.paidTo,
    required this.proof,
    required this.onPickProof,
    required this.onRemoveProof,
    required this.sent,
    required this.canSkip,
    required this.addAnother,
    required this.onAddAnotherChanged,
  });

  final GlobalKey<FormState> formKey;
  final bool showErrors;
  final bool enabled;
  final PaymentMethod method;
  final ValueChanged<PaymentMethod> onMethodChanged;
  final TextEditingController reference;
  final TextEditingController amount;
  final DateTime? paidOn;
  final VoidCallback onPickDate;
  final TextEditingController paidWhen;
  final TextEditingController paidTo;
  final PickedDocument? proof;
  final VoidCallback onPickProof;
  final VoidCallback onRemoveProof;

  /// Payments sent before (when the club edits its registration).
  final List<Payment> sent;

  /// A payment is still waiting or confirmed, so a new one is optional.
  final bool canSkip;
  final bool addAnother;
  final ValueChanged<bool> onAddAnotherChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA);
    const gap = SizedBox(height: 14);
    final showForm = !canSkip || addAnother;
    final proof = this.proof;

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
                const _FeeCard(),
                if (sent.isNotEmpty) ...[
                  const StepHeading('Payments sent', top: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outline),
                    ),
                    child: Column(
                      children: [
                        for (final (i, payment) in sent.indexed)
                          PaymentRow(payment: payment, divider: i > 0),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (canSkip)
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      value: addAnother,
                      onChanged: enabled ? onAddAnotherChanged : null,
                      title: const Text('Add another payment'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'The FA could not find your payment. Send it again '
                        'below, with the correct details.',
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
                if (showForm) ...[
                  StepHeading('How did you pay?', top: sent.isEmpty ? 18 : 12),
                  RadioGroup<PaymentMethod>(
                    groupValue: method,
                    onChanged: (value) {
                      if (enabled && value != null) onMethodChanged(value);
                    },
                    child: Column(
                      children: [
                        for (final option in PaymentMethod.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ChoiceCard<PaymentMethod>(
                              value: option,
                              selected: method == option,
                              title: option.label,
                              description: option.description,
                              onTap: enabled
                                  ? () => onMethodChanged(option)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (method == PaymentMethod.momo) ...[
                    TextFormField(
                      controller: reference,
                      enabled: enabled,
                      decoration: const InputDecoration(
                        labelText: 'Transaction ID *',
                        hintText: 'e.g. 8123456789',
                        helperText: 'From the MoMo or bank message',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[A-Za-z0-9.-]'),
                        ),
                        LengthLimitingTextInputFormatter(30),
                      ],
                      validator: (value) => (value?.trim().length ?? 0) < 4
                          ? 'Enter the transaction ID'
                          : null,
                    ),
                    gap,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _AmountField(
                            controller: amount,
                            enabled: enabled,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            // Rebuilt with the new text when a date is picked
                            key: ValueKey(paidOn),
                            initialValue:
                                paidOn == null ? '' : formatDate(paidOn!),
                            readOnly: true,
                            enabled: enabled,
                            onTap: onPickDate,
                            decoration: const InputDecoration(
                              labelText: 'Date paid *',
                              suffixIcon:
                                  Icon(Icons.calendar_today_outlined, size: 18),
                            ),
                            validator: (_) =>
                                paidOn == null ? 'Choose the date' : null,
                          ),
                        ),
                      ],
                    ),
                    gap,
                    FileUploadRow(
                      title: 'Proof (optional)',
                      subtitle: proof == null
                          ? 'Screenshot of the payment message'
                          : '${proof.name} · ${proof.sizeText}',
                      buttonLabel: proof == null ? 'Add photo' : 'Change',
                      isPdf: false,
                      hasFile: proof != null,
                      onPressed: enabled ? onPickProof : null,
                      onRemove: proof != null && enabled ? onRemoveProof : null,
                    ),
                  ],
                  if (method == PaymentMethod.cash) ...[
                    _AmountField(controller: amount, enabled: enabled),
                    gap,
                    TextFormField(
                      controller: paidTo,
                      enabled: enabled,
                      decoration: const InputDecoration(
                        labelText: 'Paid to (optional)',
                        hintText: 'e.g. the FA secretary',
                        helperText: 'Who received the money',
                      ),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(60)],
                    ),
                    gap,
                    TextFormField(
                      controller: paidWhen,
                      enabled: enabled,
                      decoration: const InputDecoration(
                        labelText: 'About when? (optional)',
                        hintText: 'e.g. September 2026',
                      ),
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                    ),
                  ],
                  gap,
                ],
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
                          'The FA checks every payment against its own '
                          'records. Each payment it confirms gets a receipt '
                          'number in the app. Any balance stays on your team '
                          'under More › Season fee, with a reminder every 3 '
                          'days until it is paid.',
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

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: 'Amount paid (GH₵) *',
        hintText: 'e.g. 500',
        helperText: 'Up to ${cedis(Season.fee).replaceFirst('GH₵ ', '')}',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      validator: validateAmount,
    );
  }
}

/// "2026/27 season fee · GH₵ 1,000", the MoMo number with Copy.
class _FeeCard extends StatelessWidget {
  const _FeeCard();

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: Season.momoNumber));
    if (context.mounted) AppToast.success(context, 'Number copied.');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final link = isDark ? const Color(0xFF7DBBFA) : scheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '${Season.label(Season.current)} season fee',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                cedis(Season.fee),
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCD116),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'MoMo',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay to GEDFA',
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        Season.momoNumber,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _copy(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: scheme.outline),
                    foregroundColor: link,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Copy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Paid every season. You can pay in parts: send what you have '
            'now and add the rest later.',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
