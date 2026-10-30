import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/payments/data/payment_repository.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/payments/presentation/widgets/fee_progress.dart';
import 'package:gedfa_connect/features/payments/presentation/widgets/payment_row.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:go_router/go_router.dart';

/// Board R8: the team's season fee (More › Season fee). How much is
/// confirmed, what is left, every payment with its receipt or the FA's
/// reason, and "Add a payment".
class SeasonFeeScreen extends ConsumerWidget {
  const SeasonFeeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(myTeamProvider).value;
    // The fee is kept under the account that registered the team
    final uid =
        team?.requestUid ?? ref.watch(authStateProvider).value?.uid ?? '';
    final summary = ref.watch(feeSummaryProvider(uid)).value ??
        const FeeSummary(confirmed: 0, fee: Season.fee);
    final paymentsAsync = ref.watch(clubPaymentsProvider(uid));

    return Scaffold(
      appBar: GedfaAppBar(title: 'Season fee', subtitle: team?.name),
      bottomNavigationBar: summary.isPaid
          ? null
          : _BottomButton(
              onPressed: () => context.push(Routes.teamAddPayment),
            ),
      body: paymentsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (payments) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryCard(summary: summary),
                  const SizedBox(height: 14),
                  _Banner(summary: summary),
                  const SizedBox(height: 22),
                  const SectionTitle('Payments'),
                  if (payments.isEmpty)
                    const EmptyView(
                      icon: Icons.receipt_long_outlined,
                      title: 'No payments yet',
                      message: 'Add a payment once you have paid GEDFA.',
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (final (i, payment) in payments.indexed)
                            PaymentRow(payment: payment, divider: i > 0),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "2026/27 season · GH₵ 600 of 1,000 · GH₵ 400 left" with the bar.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final FeeSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final greens = feeGreens(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${Season.label(Season.current)} season',
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: cedis(summary.confirmed),
                    children: [
                      TextSpan(
                        text: ' of ${cedis(summary.fee).substring(4)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  style: textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Text(
                summary.isPaid ? 'Fully paid' : '${cedis(summary.left)} left',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: summary.isPaid ? greens.ink : scheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FeeBar(summary: summary),
          const SizedBox(height: 10),
          Text(
            'Counts confirmed payments only. Pay to MoMo '
            '${Season.momoNumber}.',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold while something is left, green once it's all paid.
class _Banner extends StatelessWidget {
  const _Banner({required this.summary});

  final FeeSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greens = feeGreens(context);
    final (bg, ink) = summary.isPaid
        ? (greens.bg, greens.ink)
        : isDark
            ? (const Color(0xFF3D3410), const Color(0xFFF5D25B))
            : (const Color(0xFFFFF6CC), const Color(0xFF5C4700));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            summary.isPaid
                ? Icons.verified_outlined
                : Icons.notifications_outlined,
            size: 18,
            color: ink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              summary.isPaid
                  ? TextSpan(
                      children: [
                        TextSpan(
                          text: 'Fully paid for '
                              '${Season.label(Season.current)}. ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: 'Thank you!'),
                      ],
                    )
                  : TextSpan(
                      children: [
                        TextSpan(
                          text: '${cedis(summary.left)} left. ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text: 'We remind you every 3 days until the fee is '
                              'fully paid. The FA can also send a reminder.',
                        ),
                      ],
                    ),
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12.5,
                height: 1.5,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  const _BottomButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FilledButton(
                onPressed: onPressed,
                child: const Text('Add a payment'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
