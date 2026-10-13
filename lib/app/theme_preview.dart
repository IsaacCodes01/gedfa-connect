import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/core/widgets/status_badge.dart';

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