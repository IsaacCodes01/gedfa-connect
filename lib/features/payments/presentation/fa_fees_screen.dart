import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/count_tabs.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/payments/data/payment_repository.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/payments/presentation/widgets/fee_progress.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:go_router/go_router.dart';

enum _Filter { all, owing, paid }

/// FA: More › Season fees. Every approved team with what it has paid this
/// season, what's left and how many payments wait for the FA. Teams with
/// payments to confirm come first, then the ones that owe the most.
class FaFeesScreen extends ConsumerStatefulWidget {
  const FaFeesScreen({super.key});

  @override
  ConsumerState<FaFeesScreen> createState() => _FaFeesScreenState();
}

class _FaFeesScreenState extends ConsumerState<FaFeesScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(allTeamsProvider);
    final totals = ref.watch(seasonTotalsProvider).value ?? const {};
    final waiting = ref.watch(waitingPaymentsProvider).value ?? const [];

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Season fees',
        subtitle: '${Season.label(Season.current)} · '
            '${cedis(Season.fee)} per team',
      ),
      body: teamsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (teams) {
          final rows = [
            for (final team in teams)
              _Row(
                team: team,
                summary: FeeSummary(
                  confirmed: totals[team.requestUid] ?? 0,
                  fee: Season.fee,
                ),
                toConfirm: waiting
                    .where((p) => p.requestUid == team.requestUid)
                    .length,
              ),
          ]..sort((a, b) {
              // To confirm first, then who owes the most, then A to Z
              final c = b.toConfirm.compareTo(a.toConfirm);
              if (c != 0) return c;
              final d = b.summary.left.compareTo(a.summary.left);
              return d != 0 ? d : a.team.name.compareTo(b.team.name);
            });
          final owing = rows.where((r) => !r.summary.isPaid).toList();
          final paid = rows.where((r) => r.summary.isPaid).toList();
          final shown = switch (_filter) {
            _Filter.all => rows,
            _Filter.owing => owing,
            _Filter.paid => paid,
          };
          final collected =
              rows.fold<int>(0, (sum, r) => sum + r.summary.confirmed);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Totals(
                      collected: collected,
                      expected: rows.length * Season.fee,
                      toConfirm: waiting.length,
                    ),
                    const SizedBox(height: 14),
                    CountTabs<_Filter>(
                      tabs: [
                        CountTab(
                          value: _Filter.all,
                          label: 'All',
                          count: rows.length,
                        ),
                        CountTab(
                          value: _Filter.owing,
                          label: 'Owing',
                          count: owing.length,
                          highlight: true,
                        ),
                        CountTab(
                          value: _Filter.paid,
                          label: 'Paid',
                          count: paid.length,
                        ),
                      ],
                      selected: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(height: 12),
                    if (shown.isEmpty)
                      const EmptyView(
                        icon: Icons.payments_outlined,
                        title: 'No teams here',
                        message: 'Approved teams appear here with their '
                            'season fee.',
                      )
                    else
                      for (final row in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TeamFeeTile(row: row),
                        ),
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

class _Row {
  const _Row({
    required this.team,
    required this.summary,
    required this.toConfirm,
  });

  final Team team;
  final FeeSummary summary;
  final int toConfirm;
}

/// "GH₵ 6,500 collected of 9,000 · 3 payments to confirm"
class _Totals extends StatelessWidget {
  const _Totals({
    required this.collected,
    required this.expected,
    required this.toConfirm,
  });

  final int collected;
  final int expected;
  final int toConfirm;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

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
            'Collected (confirmed)',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: cedis(collected),
              children: [
                TextSpan(
                  text: ' of ${cedis(expected).substring(4)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            style: textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, fontSize: 24),
          ),
          const SizedBox(height: 10),
          FeeBar(
            summary: FeeSummary(
              confirmed: collected,
              fee: expected == 0 ? 1 : expected,
            ),
          ),
          if (toConfirm > 0) ...[
            const SizedBox(height: 10),
            Text(
              toConfirm == 1
                  ? '1 payment to confirm'
                  : '$toConfirm payments to confirm',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One team: logo, name, "GH₵ 600 of 1,000", bar, and a gold
/// "2 to confirm" or a green "Paid".
class _TeamFeeTile extends StatelessWidget {
  const _TeamFeeTile({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greens = feeGreens(context);
    final team = row.team;
    final summary = row.summary;
    final (String? chip, Color? bg, Color? ink) = row.toConfirm > 0
        ? (
            '${row.toConfirm} to confirm',
            isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC),
            isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700),
          )
        : summary.isPaid
            ? ('Paid', greens.bg, greens.ink)
            : (null, null, null);

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: () => context.go(Routes.adminTeamFee(team.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              TeamLogo(
                label: initialsFor(team.name),
                color: team.logoColor,
                url: team.logoUrl,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (chip != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              chip.toUpperCase(),
                              style: TextStyle(
                                color: ink,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FeeBar(summary: summary, height: 6),
                    const SizedBox(height: 4),
                    Text(
                      summary.isPaid
                          ? '${cedis(summary.confirmed)} · fully paid'
                          : '${cedis(summary.confirmed)} paid · '
                              '${cedis(summary.left)} left',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
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
