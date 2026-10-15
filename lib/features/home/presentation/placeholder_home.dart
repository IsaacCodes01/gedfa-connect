import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';

class PlaceholderHome extends ConsumerWidget {
  const PlaceholderHome({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final authUser = ref.watch(authStateProvider).value;
    final appUser = ref.watch(appUserProvider).value;

    return Scaffold(
      appBar: GedfaAppBar(title: title),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hello, ${authUser?.displayName ?? 'there'}!',
                  style: textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Text(
                  'Email: ${authUser?.email ?? '-'}\n'
                  'Role: ${appUser?.role?.name ?? 'none'}',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(authRepositoryProvider).signOut(),
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