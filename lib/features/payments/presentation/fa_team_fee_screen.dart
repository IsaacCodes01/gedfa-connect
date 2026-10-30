import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/payments/data/payment_repository.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/payments/presentation/widgets/fa_payment_card.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:go_router/go_router.dart';

/// FA: one approved team's season fee. The same payment card as the
/// registration review (green tick, not found, record cash), plus
/// "Send reminder" while something is left to pay.
class FaTeamFeeScreen extends ConsumerWidget {
  const FaTeamFeeScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamByIdProvider(teamId));

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Season fee',
        subtitle: teamAsync.value?.name,
        leading: BackButton(onPressed: () => context.go(Routes.adminFees)),
      ),
      body: teamAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (team) {
          final requestUid = team?.requestUid;
          if (team == null || requestUid == null) {
            return const EmptyView(
              icon: Icons.search_off_rounded,
              title: 'Team not found',
              message: 'It may have been removed.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              ResponsiveCenter(
                maxWidth: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle(
                      '${Season.label(Season.current)} season fee',
                    ),
                    FaPaymentCard(
                      requestUid: requestUid,
                      teamName: team.name,
                      teamId: team.id,
                    ),
                    const SizedBox(height: 16),
                    _ReminderButton(team: team, requestUid: requestUid),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReminderButton extends ConsumerStatefulWidget {
  const _ReminderButton({required this.team, required this.requestUid});

  final Team team;
  final String requestUid;

  @override
  ConsumerState<_ReminderButton> createState() => _ReminderButtonState();
}

class _ReminderButtonState extends ConsumerState<_ReminderButton> {
  bool _busy = false;

  Future<void> _send(FeeSummary summary) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send a reminder?'),
        content: Text(
          '${widget.team.name} gets "${cedis(summary.left)} left to pay" '
          'in their bell. Several reminders on the same day count as one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(paymentRepositoryProvider).sendReminder(
            teamId: widget.team.id,
            teamName: widget.team.name,
            left: summary.left,
          );
      if (mounted) {
        AppToast.success(context, 'Reminder sent to ${widget.team.name}.');
      }
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(feeSummaryProvider(widget.requestUid)).value;
    if (summary == null || summary.isPaid) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: _busy ? null : () => _send(summary),
      icon: const Icon(Icons.notifications_active_outlined),
      label: Text('Send reminder (${cedis(summary.left)} left)'),
    );
  }
}
