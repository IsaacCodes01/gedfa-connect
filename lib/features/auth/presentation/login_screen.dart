import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/connectivity/connectivity_provider.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/features/auth/data/auth_error_messages.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/startup_gate.dart';
import 'package:gedfa_connect/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:gedfa_connect/features/auth/presentation/widgets/google_popup_guard.dart';

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

  /// RU1: arriving from the start-up screen (the logo glided up), the card
  /// slides up. Asked once.
  late final bool _slideCardIn = ref
      .read(startupGateProvider.notifier)
      .takeGlide();

  bool get _isBusy => _isLoading || _isGoogleLoading;

  /// Each tap on "Continue with Google" gets a number, so a late answer
  /// from an older, abandoned window can't change the screen.
  int _googleAttempt = 0;

  /// Stops the spinner if the Google window is closed without signing in.
  late final _googleGuard = GooglePopupGuard(onGaveUp: _googleGaveUp);

  void _googleGaveUp() {
    if (!mounted || !_isGoogleLoading) return;
    _googleAttempt++; // ignore whatever the abandoned window does later
    _googleGuard.stop();
    setState(() => _isGoogleLoading = false);
    AppToast.info(context, 'Google sign-in was cancelled.');
  }

  @override
  void dispose() {
    _googleGuard.stop();
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
    final attempt = ++_googleAttempt;
    _googleGuard.start();

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted || attempt != _googleAttempt) return;
      AppToast.success(context, 'Welcome!');
    } catch (error) {
      // Already stopped by the guard, or replaced by a newer attempt
      if (!mounted || attempt != _googleAttempt) return;
      if (isInfoAuthError(error)) {
        AppToast.info(context, authErrorMessage(error));
      } else {
        AppToast.error(context, authErrorMessage(error));
      }
    } finally {
      if (attempt == _googleAttempt) {
        _googleGuard.stop();
        if (mounted) setState(() => _isGoogleLoading = false);
      }
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
      heroHeight: AuthScaffold.loginHeroHeight,
      slideCardIn: _slideCardIn,
      // The see-through logo on the navy header, where the start-up
      // screen's logo glides to (RU1)
      hero: Image.asset(
        'assets/images/gedfa_logo.png',
        width: AuthScaffold.loginLogoWidth,
        semanticLabel: 'GEDFA, Gomoa East District Football Association',
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