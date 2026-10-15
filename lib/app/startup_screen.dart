import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider);

    if (appUser.hasError && !appUser.isLoading) {
      return Scaffold(
        body: ErrorView(
          message:
              "We couldn't load your account. Check your connection and try again.",
          onRetry: () => ref.invalidate(appUserProvider),
        ),
      );
    }

    return const Scaffold(body: LoadingView());
  }
}