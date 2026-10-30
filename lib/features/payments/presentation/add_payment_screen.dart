import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/connectivity/connectivity_provider.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/files/picked_document.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/payments/data/payment_repository.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/payment_step.dart';
import 'package:go_router/go_router.dart';

/// An approved team adds a payment (More › Season fee › Add a payment).
/// The same form as the registration's Payment step (board R6).
class AddPaymentScreen extends ConsumerStatefulWidget {
  const AddPaymentScreen({super.key});

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  PaymentMethod _method = PaymentMethod.momo;
  final _reference = TextEditingController();
  final _amount = TextEditingController();
  final _paidWhen = TextEditingController();
  final _paidTo = TextEditingController();
  DateTime? _paidOn;
  PickedDocument? _proof;
  bool _showErrors = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_reference, _amount, _paidWhen, _paidTo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _showErrors = true);
      AppToast.warning(context, 'Please fix the highlighted fields.');
      return;
    }
    final online = switch (ref.read(isOnlineProvider)) {
      AsyncData(:final value) => value,
      _ => true,
    };
    if (!online) {
      AppToast.warning(context, "You're offline. Connect to send it.");
      return;
    }
    final team = ref.read(myTeamProvider).value;
    final uid = team?.requestUid ?? ref.read(authStateProvider).value?.uid;
    if (team == null || uid == null) return;

    setState(() => _busy = true);
    try {
      final payments = ref.read(paymentRepositoryProvider);
      final proof = _proof;
      String? proofUrl;
      if (_method == PaymentMethod.momo && proof != null) {
        proofUrl = await payments.uploadProof(uid: uid, bytes: proof.bytes);
      }
      await payments.addForTeam(
        requestUid: uid,
        teamId: team.id,
        teamName: team.name,
        proofUrl: proofUrl,
        draft: PaymentDraft(
          method: _method,
          amount: _method == PaymentMethod.before
              ? null
              : int.tryParse(_amount.text.trim()),
          reference: _method == PaymentMethod.momo ? _reference.text : null,
          paidOn: _method == PaymentMethod.momo ? _paidOn : null,
          paidWhen: _method == PaymentMethod.cash ? _paidWhen.text : null,
          paidTo: _method == PaymentMethod.cash ? _paidTo.text : null,
        ),
      );
      if (!mounted) return;
      AppToast.success(context, 'Payment sent. The FA will confirm it.');
      context.pop();
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Add a payment',
        leading: CloseButton(onPressed: () => context.pop()),
      ),
      body: PaymentStep(
        formKey: _formKey,
        showErrors: _showErrors,
        enabled: !_busy,
        method: _method,
        onMethodChanged: (value) => setState(() => _method = value),
        reference: _reference,
        amount: _amount,
        paidOn: _paidOn,
        onPickDate: () async {
          final picked = await pickPaymentDate(context, _paidOn);
          if (picked != null && mounted) setState(() => _paidOn = picked);
        },
        paidWhen: _paidWhen,
        paidTo: _paidTo,
        proof: _proof,
        onPickProof: () async {
          final proof = await pickPaymentProof(context);
          if (proof != null && mounted) setState(() => _proof = proof);
        },
        onRemoveProof: () => setState(() => _proof = null),
        sent: const [],
        canSkip: false,
        addAnother: false,
        onAddAnotherChanged: (_) {},
      ),
      bottomNavigationBar: Container(
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
                constraints: const BoxConstraints(maxWidth: 480),
                child: FilledButton(
                  onPressed: _busy ? null : _send,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Send payment'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
