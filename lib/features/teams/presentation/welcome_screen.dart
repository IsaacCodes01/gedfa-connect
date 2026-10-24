import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/people/presentation/invite_accept_view.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/competition_picker.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    final requestAsync = ref.watch(myTeamRequestProvider);
    final inviteAsync = ref.watch(myOpenInviteProvider);

    // Invited by the FA (2.6)? Then this screen is "Accept invitation",
    // not "Register your team". Wait for the answer to avoid a flicker.
    if (!inviteAsync.hasValue && !inviteAsync.hasError) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final invite = inviteAsync.value;
    if (invite != null) return InviteAcceptView(invite: invite);

// Still waiting for Firestore's first answer: show a spinner, not the intro
if (!requestAsync.hasValue && !requestAsync.hasError) {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

final request = requestAsync.value; // null = really no request → intro

    Future<void> refresh() async {
      ref.invalidate(myTeamRequestProvider);
      try {
        await ref.read(myTeamRequestProvider.future);
      } catch (_) {
        // The screen shows the error itself.
      }
    }

    final footer = _SignedInFooter(
      email: authUser?.email ?? '',
      onLogOut: () => ref.read(authRepositoryProvider).signOut(),
    );

    if (request == null && requestAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (request == null && requestAsync.hasError) {
      return AuthScaffold(
        heroHeight: 200,
        hero: const _HeroTitle('Welcome'),
        onRefresh: refresh,
        footer: footer,
        card: _ErrorCard(
          message: appErrorMessage(requestAsync.error!),
          onRetry: refresh,
        ),
      );
    }

    if (request == null) {
      return AuthScaffold(
        heroHeight: 250,
        hero: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/gedfa_logo.jpg',
            width: 200,
            semanticLabel: 'GEDFA, Gomoa East District Football Association',
          ),
        ),
        onRefresh: refresh,
        footer: footer,
        card: _IntroCard(name: authUser?.displayName),
      );
    }

    return AuthScaffold(
      heroHeight: 200,
      hero: const _HeroTitle('Your registration'),
      onRefresh: refresh,
      footer: footer,
      card: _StatusCard(request: request),
    );
  }
}

// ---------- Shared bits ----------

class _HeroTitle extends StatelessWidget {
  const _HeroTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
    );
  }
}

class _SignedInFooter extends StatelessWidget {
  const _SignedInFooter({required this.email, required this.onLogOut});

  final String email;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Signed in as $email',
          style:
              textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        TextButton(onPressed: onLogOut, child: const Text('Log out')),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

// ---------- No request yet ----------

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, size: 30, color: scheme.primary),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Welcome, ${name ?? 'coach'}!',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          "You're signed in. Let's get your team into the GEDFA league.",
          textAlign: TextAlign.center,
          style:
              textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        const _HowStep(
          number: 1,
          title: 'Register your team',
          text: 'Club details, kits and officials · about 5 minutes',
        ),
        const SizedBox(height: 14),
        const _HowStep(
          number: 2,
          title: 'FA review',
          text: 'The GEDFA office checks and approves your team',
        ),
        const SizedBox(height: 14),
        const _HowStep(
          number: 3,
          title: 'Build your squad',
          text: 'Add players once your team is approved',
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => context.go(Routes.registerTeam),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Register your team'),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.number,
    required this.title,
    required this.text,
  });

  final int number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                text,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------- Request exists ----------

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.request});

  final TeamRequest request;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = request.status;
    final reason = request.rejectionReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TeamLogo(
            label: initialsFor(request.teamName),
            color: request.homeKit.primary,
            url: request.logoUrl,
            size: 76,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          request.teamName,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          '${request.shortName} · ${request.town}',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        CompetitionChips(
          competitions: request.categories,
          compact: true,
          center: true,
        ),
        const SizedBox(height: 12),
        Center(child: _StatusPill(status: status)),
        if (status == ApprovalStatus.rejected &&
            reason != null &&
            reason.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason from the FA',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(reason, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _Timeline(request: request),
        const SizedBox(height: 16),
        if (status == ApprovalStatus.rejected)
          FilledButton.icon(
            onPressed: () => context.go(Routes.registerTeam),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit and resubmit'),
          )
        else if (status == ApprovalStatus.pending)
          OutlinedButton.icon(
            onPressed: () => context.go(Routes.registerTeam),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('View or edit registration'),
          ),
        const SizedBox(height: 8),
        Text(
          'Pull down to refresh',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (label, icon, background, foreground) = switch (status) {
      ApprovalStatus.pending => (
          'Pending FA review',
          Icons.schedule_rounded,
          isDark ? const Color(0xFF3A3000) : AppColors.pendingBg,
          isDark ? AppColors.ghanaGold : AppColors.pendingText,
        ),
      ApprovalStatus.rejected => (
          'Changes requested',
          Icons.error_outline_rounded,
          isDark ? const Color(0xFF3D1218) : AppColors.rejectedBg,
          isDark ? const Color(0xFFFF8A94) : AppColors.rejectedText,
        ),
      ApprovalStatus.approved => (
          'Approved',
          Icons.check_circle_outline_rounded,
          isDark ? const Color(0xFF0E3324) : AppColors.approvedBg,
          isDark ? AppColors.darkGreen : AppColors.approvedText,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, problem, todo }

class _Timeline extends StatelessWidget {
  const _Timeline({required this.request});

  final TeamRequest request;

  @override
  Widget build(BuildContext context) {
    final status = request.status;
    final sentAt = request.updatedAt ?? request.createdAt;

    final items = [
      (
        _StepState.done,
        'Registration sent',
        sentAt == null ? 'Just now' : formatDateTime(sentAt),
      ),
      switch (status) {
        ApprovalStatus.pending => (
            _StepState.current,
            'FA review',
            "Usually within a few days. You'll see the result here.",
          ),
        ApprovalStatus.rejected => (
            _StepState.problem,
            'Changes requested',
            'Edit your registration and send it again.',
          ),
        ApprovalStatus.approved => (
            _StepState.done,
            'FA review',
            'Your team was approved.',
          ),
      },
      (
        status == ApprovalStatus.approved ? _StepState.done : _StepState.todo,
        'Team approved',
        'Then you can add your players',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _TimelineItem(
            state: items[i].$1,
            title: items[i].$2,
            text: items[i].$3,
            isLast: i == items.length - 1,
          ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.state,
    required this.title,
    required this.text,
    required this.isLast,
  });

  final _StepState state;
  final String title;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.darkGreen : AppColors.approvedText;
    final gold = isDark ? AppColors.ghanaGold : AppColors.pendingText;

    final Widget dot = switch (state) {
      _StepState.done => CircleAvatar(
          radius: 13,
          backgroundColor: green,
          child: Icon(Icons.check_rounded, size: 16, color: scheme.surface),
        ),
      _StepState.current || _StepState.problem => Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: state == _StepState.current ? gold : scheme.error,
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 4,
            backgroundColor:
                state == _StepState.current ? gold : scheme.error,
          ),
        ),
      _StepState.todo => Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outline, width: 2),
          ),
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            dot,
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: scheme.outline,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: state == _StepState.todo
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
                Text(
                  text,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}