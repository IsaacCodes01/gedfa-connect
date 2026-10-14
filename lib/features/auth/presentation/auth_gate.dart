import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/presentation/login_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/signed_in_placeholder.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return switch (authState) {
      AsyncData(:final value) when value == null => const LoginScreen(),
      AsyncData(:final value) => SignedInPlaceholder(user: value!),
      AsyncError() => Scaffold(
          body: ErrorView(
            message: "We couldn't check your login. Please try again.",
            onRetry: () => ref.invalidate(authStateProvider),
          ),
        ),
      _ => const Scaffold(body: LoadingView()),
    };
  }
}