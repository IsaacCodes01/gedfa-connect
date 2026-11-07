import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/features/dashboard/domain/fa_waiting.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';
import 'package:go_router/go_router.dart';

/// "Needs you" (2.12a): one row for each kind of thing waiting for the FA,
/// with a gold number. A row with 0 is left out. Tapping a row opens the
/// screen where it is decided.
class NeedsYouCard extends ConsumerWidget {
  const NeedsYouCard({super.key, required this.waiting});

  final FaWaiting waiting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(upcomingScreeningsProvider).value?.firstOrNull;

    final rows = [
      if (waiting.newTeams > 0)
        _Need(
          icon: Icons.shield_rounded,
          tone: AccentTone.blue,
          label: 'New teams',
          detail: 'Registration requests to review',
          count: waiting.newTeams,
          route: Routes.admin,
        ),
      if (waiting.teamChanges > 0)
        _Need(
          icon: Icons.edit_note_rounded,
          tone: AccentTone.violet,
          label: 'Team changes',
          detail: 'Name, short name, logo, competition',
          count: waiting.teamChanges,
          route: Routes.adminChanges,
        ),
      if (waiting.players > 0)
        _Need(
          icon: Icons.how_to_reg_rounded,
          tone: AccentTone.green,
          label: 'Players to approve',
          detail: 'Division players, new and changed',
          count: waiting.players,
          route: Routes.adminPlayers,
        ),
      if (waiting.screening > 0)
        _Need(
          icon: Icons.child_care_rounded,
          tone: AccentTone.gold,
          label: 'Waiting for screening',
          detail: next == null
              ? 'No screening day planned yet'
              : 'Next screening day: ${next.dateText}, ${next.venue}',
          count: waiting.screening,
          route: Routes.adminScreening,
        ),
      if (waiting.payments > 0)
        _Need(
          icon: Icons.payments_rounded,
          tone: AccentTone.green,
          label: 'Payments to confirm',
          detail: 'Season fee payments sent by teams',
          count: waiting.payments,
          route: Routes.adminFees,
        ),
      if (waiting.correctionsBack > 0)
        _Need(
          icon: Icons.assignment_return_rounded,
          tone: AccentTone.red,
          label: 'Corrections sent back',
          detail: 'Teams that fixed what you asked',
          count: waiting.correctionsBack,
          route: Routes.adminChanges,
        ),
    ];

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: dashboardBorder(context),
              ),
            _NeedRow(need: rows[i]),
          ],
        ],
      ),
    );
  }
}

/// Shown instead of [NeedsYouCard] when nothing is waiting.
class AllCaughtUpCard extends StatelessWidget {
  const AllCaughtUpCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AccentTone.green.background(isDark),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 30,
              color: AccentTone.green.foreground(isDark),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All caught up',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Nothing is waiting for the FA right now.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashboard's white (dark: navy) card: soft border, round corners
/// and a light shadow. 2.12b's tiles and charts use it too.
class DashboardCard extends StatelessWidget {
  const DashboardCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dashboardBorder(context)),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          else ...[
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ],
      ),
      child: child,
    );
  }
}

Color dashboardBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkCardBorder
        : AppColors.cardBorder;

/// A coloured square with an icon (the start of each row and tile).
class AccentIcon extends StatelessWidget {
  const AccentIcon({super.key, required this.icon, required this.tone});

  final IconData icon;
  final AccentTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: tone.background(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: tone.foreground(isDark)),
    );
  }
}

class _Need {
  const _Need({
    required this.icon,
    required this.tone,
    required this.label,
    required this.detail,
    required this.count,
    required this.route,
  });

  final IconData icon;
  final AccentTone tone;
  final String label;
  final String detail;
  final int count;
  final String route;
}

class _NeedRow extends StatelessWidget {
  const _NeedRow({required this.need});

  final _Need need;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: '${need.label}, ${need.count} waiting',
      excludeSemantics: true,
      child: InkWell(
        // go, not push: these screens are tabs (Teams, Players) or
        // More pages, and Back there works as it does today
        onTap: () => context.go(need.route),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              AccentIcon(icon: need.icon, tone: need.tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      need.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      need.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 30),
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ghanaGold,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  need.count > 99 ? '99+' : '${need.count}',
                  style: const TextStyle(
                    color: Color(0xFF3A2C00),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
