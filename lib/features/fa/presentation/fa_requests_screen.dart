import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/count_tabs.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/competition_picker.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:go_router/go_router.dart';

/// FA home, Teams tab: every team registration request, split into
/// Pending / Rejected / Approved, with search.
class FaRequestsScreen extends ConsumerStatefulWidget {
  const FaRequestsScreen({super.key});

  @override
  ConsumerState<FaRequestsScreen> createState() => _FaRequestsScreenState();
}

class _FaRequestsScreenState extends ConsumerState<FaRequestsScreen> {
  ApprovalStatus _tab = ApprovalStatus.pending;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allTeamRequestsProvider);

    return Scaffold(
      appBar: const GedfaAppBar(
        title: 'Team requests',
        subtitle: 'Gomoa East District FA',
      ),
      body: requestsAsync.when(
        data: _body,
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: appErrorMessage(error),
          onRetry: () => ref.invalidate(allTeamRequestsProvider),
        ),
      ),
    );
  }

  Widget _body(List<TeamRequest> all) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    int countOf(ApprovalStatus status) =>
        all.where((request) => request.status == status).length;

    // Filter by tab and search
    final query = _search.trim().toLowerCase();
    final shown = all.where((request) {
      if (request.status != _tab) return false;
      if (query.isEmpty) return true;
      return request.teamName.toLowerCase().contains(query) ||
          request.town.toLowerCase().contains(query) ||
          request.shortName.toLowerCase().contains(query);
    }).toList();

    // Pending: oldest first (first come, first served).
    // Rejected and approved: most recently changed first.
    DateTime when(TeamRequest r) =>
        r.updatedAt ?? r.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    shown.sort(
      _tab == ApprovalStatus.pending
          ? (a, b) => when(a).compareTo(when(b))
          : (a, b) => when(b).compareTo(when(a)),
    );

    final hint = switch (_tab) {
      ApprovalStatus.pending =>
        'Oldest first. Open a request to check it.',
      ApprovalStatus.rejected => 'Waiting for the club to fix and send again.',
      ApprovalStatus.approved => 'These clubs are now teams in the league.',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CountTabs<ApprovalStatus>(
                tabs: [
                  for (final status in ApprovalStatus.values)
                    CountTab(
                      value: status,
                      label: _tabLabel(status),
                      count: countOf(status),
                      // Gold bubble = waiting for the FA
                      highlight: status == ApprovalStatus.pending,
                    ),
                ],
                selected: _tab,
                onChanged: (status) => setState(() => _tab = status),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by team or town',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  hint,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.inbox_outlined,
                    title: query.isEmpty
                        ? 'No ${_tabLabel(_tab).toLowerCase()} requests'
                        : 'No match',
                    message: query.isEmpty
                        ? (_tab == ApprovalStatus.pending
                            ? 'New team registrations will appear here.'
                            : 'Nothing here yet.')
                        : 'No request matches "$_search".',
                  ),
                )
              else
                for (final request in shown) ...[
                  _RequestCard(
                    request: request,
                    onTap: () => context.go(Routes.adminRequest(request.uid)),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ],
    );
  }

  static String _tabLabel(ApprovalStatus status) => switch (status) {
        ApprovalStatus.pending => 'Pending',
        ApprovalStatus.rejected => 'Rejected',
        ApprovalStatus.approved => 'Approved',
      };
}

/// One request in the list: logo, name, short name · town, competitions,
/// the rejection reason (if any) and when it was sent or changed.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final TeamRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final reason = request.rejectionReason;
    final when = request.updatedAt ?? request.createdAt;

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              TeamLogo(
                label: initialsFor(request.teamName),
                color: request.homeKit.primary,
                url: request.logoUrl,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.teamName,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${request.shortName} · ${request.town}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    CompetitionChips(
                      competitions: request.categories,
                      compact: true,
                    ),
                    if (request.status == ApprovalStatus.rejected &&
                        reason != null &&
                        reason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reason: $reason',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            textTheme.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (when != null)
                    Text(
                      _relative(when),
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Today", "Yesterday", "3 days ago", then the date.
  static String _relative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final local = date.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    return formatDate(local);
  }
}
