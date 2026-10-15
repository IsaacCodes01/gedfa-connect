import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/features/auth/data/auth_error_messages.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/presentation/widgets/auth_widgets.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _cooldownSeconds = 60;

  bool _isChecking = false;
  bool _isSending = false;
  int _cooldown = 0;
  Timer? _timer;

  bool get _isBusy => _isChecking || _isSending;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _checkVerified() async {
    setState(() => _isChecking = true);

    try {
      final verified =
          await ref.read(authRepositoryProvider).reloadAndCheckVerified();
      if (!mounted) return;

      if (verified) {
        AppToast.success(context, 'Email confirmed. Welcome!');
        ref.invalidate(authStateProvider);
      } else {
        AppToast.warning(
          context,
          'Not confirmed yet. Open the link in your email, then try again.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isSending = true);

    try {
      await ref.read(authRepositoryProvider).resendVerificationEmail();
      if (!mounted) return;
      AppToast.success(
        context,
        'New link sent. Check your inbox and spam folder.',
      );
      _startCooldown();
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final email = ref.watch(authStateProvider).value?.email ?? 'your email';

    Widget spinner() => SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: scheme.primary,
          ),
        );

    return AuthScaffold(
      heroHeight: 240,
      hero: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 10),
          Text(
            'Check your email',
            style: textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              text: 'We sent a confirmation link to\n',
              style: textTheme.bodyLarge,
              children: [
                TextSpan(
                  text: email,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Open the link, then come back and tap \"I've confirmed it\". "
            "Can't find it? Check your spam folder.",
            style: textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isBusy ? null : _checkVerified,
            child: _isChecking ? spinner() : const Text("I've confirmed it"),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isBusy || _cooldown > 0 ? null : _resend,
            child: _isSending
                ? spinner()
                : Text(
                    _cooldown > 0
                        ? 'Resend link in ${_cooldown}s'
                        : 'Resend link',
                  ),
          ),
        ],
      ),
      footer: Center(
        child: TextButton(
          onPressed: _isBusy
              ? null
              : () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Use a different account'),
        ),
      ),
    );
  }
}