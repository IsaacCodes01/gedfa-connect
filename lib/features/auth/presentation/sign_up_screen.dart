import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/connectivity/connectivity_provider.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/features/auth/data/auth_error_messages.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/presentation/widgets/auth_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isOnline => switch (ref.read(isOnlineProvider)) {
        AsyncData(:final value) => value,
        _ => true,
      };

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Re-enter your password';
    if (value != _passwordController.text) return "Passwords don't match";
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    if (!_isOnline) {
      AppToast.warning(
        context,
        "You're offline. Connect to the internet to create an account.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signUp(
            name: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      AppToast.success(
        context,
        'Account created! We sent you a link to confirm your email.',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      heroHeight: 170,
      heroAlignment: Alignment.bottomLeft,
      showBack: true,
      hero: Text(
        'Create account',
        style: textTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontSize: 26,
        ),
      ),
      card: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join GEDFA Connect, then register your team for FA approval.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: 'Full name'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) =>
                    Validators.requiredField(value, 'your full name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 8 characters',
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                  ),
                ),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.newPassword,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                decoration:
                    const InputDecoration(labelText: 'Confirm password'),
                textInputAction: TextInputAction.done,
                validator: _validateConfirm,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.primary,
                        ),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 16),
              const OrDivider(),
              const SizedBox(height: 16),
              GoogleSignInButton(
                onPressed: _isLoading
                    ? null
                    : () => AppToast.info(
                          context,
                          'Google sign-in is coming soon.',
                        ),
              ),
            ],
          ),
        ),
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already have an account?',
            style: textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }
}