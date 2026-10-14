import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';

class SignedInPlaceholder extends ConsumerWidget {
  const SignedInPlaceholder({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const GedfaAppBar(title: 'GEDFA Connect'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hello, ${user.displayName ?? 'there'}!',
                  style: textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Signed in as ${user.email}',
                  style: textTheme.bodyLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  user.emailVerified
                      ? 'Email confirmed ✅'
                      : 'Email not confirmed yet',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      AppToast.info(context, "You've logged out.");
                    }
                  },
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}