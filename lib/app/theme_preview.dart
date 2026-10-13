import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/core/widgets/status_badge.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';

class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Theme preview')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Welcome back', style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Log in to manage your team.',
            style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          const TextField(decoration: InputDecoration(labelText: 'Email')),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Jersey number',
              errorText: '#9 is already taken in your squad',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () {}, child: const Text('Log in')),
          const SizedBox(height: 32),
          const SizedBox(height: 24),
          Text('Toasts', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () =>
                    AppToast.success(context, 'Team request sent to the FA'),
                child: const Text('Success'),
              ),
              OutlinedButton(
                onPressed: () =>
                    AppToast.error(context, 'Wrong email or password'),
                child: const Text('Error'),
              ),
              OutlinedButton(
                onPressed: () => AppToast.warning(
                    context, "You're offline. Changes can't be sent yet."),
                child: const Text('Warning'),
              ),
              OutlinedButton(
                onPressed: () => AppToast.info(
                    context, 'Check your email to reset your password'),
                child: const Text('Info'),
              ),
            ],
          ),
          Text('Status badges', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            children: [
              StatusBadge(status: ApprovalStatus.approved),
              StatusBadge(status: ApprovalStatus.pending),
              StatusBadge(status: ApprovalStatus.rejected),
            ],
          ),
          const SizedBox(height: 32),
          const SizedBox(height: 120, child: LoadingView()),
          const SizedBox(
            height: 200,
            child: EmptyView(
              icon: Icons.groups_outlined,
              title: 'No players yet',
              message: 'Tap "Add player" to start building your squad.',
            ),
          ),
          SizedBox(
            height: 240,
            child: ErrorView(
              message: 'Check your internet connection.',
              onRetry: () {},
            ),
          ),
        ],
      ),
    );
  }
}