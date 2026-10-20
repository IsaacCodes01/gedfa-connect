import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/more_paths.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:go_router/go_router.dart';

/// Change your sign-in email. Firebase emails a link to the NEW address;
/// the email only changes when that link is opened.
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newEmail = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _sentTo; // set when the link has been sent

  @override
  void dispose() {
    _newEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Messages that only make sense on this screen.
  String _messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Your current password is incorrect.';
        case 'email-already-in-use':
          return 'Another account already uses this email.';
      }
    }
    return appErrorMessage(error);
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final newEmail = _newEmail.text.trim().toLowerCase();
      await ref.read(authRepositoryProvider).changeEmail(
            currentPassword: _password.text,
            newEmail: newEmail,
          );
      if (mounted) setState(() => _sentTo = newEmail);
    } catch (error) {
      if (mounted) AppToast.error(context, _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentUserProvider).value?.email ?? '';
    final sentTo = _sentTo;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: const GedfaAppBar(title: 'Change email'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            ResponsiveCenter(
              child: sentTo == null
                  ? _form(context, current)
                  : _sent(context, sentTo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, String current) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TileGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current email',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(
                      current,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _newEmail,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'New email'),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            validator: (value) {
              final problem = Validators.email(value);
              if (problem != null) return problem;
              if (value!.trim().toLowerCase() == current.toLowerCase()) {
                return 'This is already your email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            enabled: !_busy,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Your current password',
              helperText:
                  'So nobody else can change it from your unlocked phone',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onFieldSubmitted: (_) => _send(),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Enter your current password'
                : null,
          ),
          const SizedBox(height: 18),
          InfoBox(
            icon: Icons.info_outline_rounded,
            color: scheme.primary,
            child: const Text(
              "We'll send a link to the new address. Your email changes only "
              'after you open it. Until then, keep logging in with the old one.',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Send confirmation link'),
          ),
        ],
      ),
    );
  }

  Widget _sent(BuildContext context, String sentTo) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF006B3F).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              size: 34,
              color: Color(0xFF006B3F),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Check your new inbox',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'We sent a link to '),
                TextSpan(
                  text: sentTo,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const TextSpan(
                  text: '. Open it on any device to finish. '
                      "Check spam if you don't see it. "
                      'You may need to log in again afterwards.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => context.go(MorePaths.of(context).profile),
            child: const Text('Back to my profile'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() {
              _sentTo = null;
              _newEmail.clear();
              _password.clear();
            }),
            child: const Text('Use a different email'),
          ),
        ],
      ),
    );
  }
}
