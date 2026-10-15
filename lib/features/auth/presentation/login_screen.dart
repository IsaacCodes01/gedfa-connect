import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/connectivity/connectivity_provider.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/features/auth/data/auth_error_messages.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/features/auth/presentation/widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool get _isBusy => _isLoading || _isGoogleLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isOnline => switch (ref.read(isOnlineProvider)) {
        AsyncData(:final value) => value,
        _ => true,
      };

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    if (!_isOnline) {
      AppToast.warning(
        context,
        "You're offline. Connect to the internet to log in.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      AppToast.success(context, 'Welcome back!');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();

    if (!_isOnline) {
      AppToast.warning(
        context,
        "You're offline. Connect to the internet to continue with Google.",
      );
      return;
    }

    setState(() => _isGoogleLoading = true);

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      AppToast.success(context, 'Welcome!');
    } catch (error) {
      if (!mounted) return;
      if (isInfoAuthError(error)) {
        AppToast.info(context, authErrorMessage(error));
      } else {
        AppToast.error(context, authErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

   void _openForgotPassword() {
    context.go(
      Routes.forgotPassword,
      extra: _emailController.text.trim(),
    );
  }

  void _openSignUp() {
    context.go(Routes.signUp);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      heroHeight: 260,
      hero: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/images/gedfa_logo.jpg',
          width: 240,
          semanticLabel: 'GEDFA, Gomoa East District Football Association',
        ),
      ),
      card: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome back', style: textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Log in to manage your team and matches.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                enabled: !_isBusy,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                enabled: !_isBusy,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (value) =>
                    Validators.requiredField(value, 'your password'),
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isBusy ? null : _openForgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: _isBusy ? null : _submit,
                child: _isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.primary,
                        ),
                      )
                    : const Text('Log in'),
              ),
              const SizedBox(height: 16),
              const OrDivider(),
              const SizedBox(height: 16),
              GoogleSignInButton(
                isLoading: _isGoogleLoading,
                onPressed: _isBusy ? null : _signInWithGoogle,
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
            'New team?',
            style: textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          TextButton(
            onPressed: _isBusy ? null : _openSignUp,
            child: const Text('Create an account'),
          ),
        ],
      ),
    );
  }
}