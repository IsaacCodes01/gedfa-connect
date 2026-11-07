import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/utils/team_name_key.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/count_tabs.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/fa_changes_view.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/fa_corrections_view.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/suspension_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/competition_picker.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/previous_name_pill.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

/// FA home, Teams tab, with a switch on top (2.10b, board P4):
/// - **New teams**: every team registration request, split into
///   Pending / Rejected / Approved, with search.
/// - **Changes**: approved teams asking for a new name, short name or
///   logo, or to add a competition ([FaChangesView]).
class FaRequestsScreen extends ConsumerStatefulWidget {
  const FaRequestsScreen({
    super.key,
    this.changes = false,
    this.fromHome = false,
  });

  /// Open on Changes (`/admin?view=changes`, e.g. from the bell)
  final bool changes;

  /// Opened from a "Needs you" row on Home: back arrow to Home (2.12a)
  final bool fromHome;

  @override
  ConsumerState<FaRequestsScreen> createState() => _FaRequestsScreenState();
}

class _FaRequestsScreenState extends ConsumerState<FaRequestsScreen> {
  late bool _changes = widget.changes;
  ApprovalStatus _tab = ApprovalStatus.pending;
  String _search = '';

  @override
  void didUpdateWidget(FaRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The tab keeps this screen alive; a new link (the bell) still decides
    if (widget.changes != oldWidget.changes) _changes = widget.changes;
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allTeamRequestsProvider);

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Teams',
        subtitle: 'Gomoa East District FA',
        leading: widget.fromHome ? const BackToHomeButton() : null,
        actions: const [NotificationBell()],
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
    // Approved teams may have a new name or short name (2.10c)
    final teams = {
      for (final team in ref.watch(allTeamsProvider).value ?? const <Team>[])
        team.id: team,
    };
    final shown = all.where((request) {
      if (request.status != _tab) return false;
      if (query.isEmpty) return true;
      final team = teams[teamNameKey(request.teamName)];
      if (team != null &&
          (team.name.toLowerCase().contains(query) ||
              team.shortName.toLowerCase().contains(query))) {
        return true;
      }
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

    // New teams | Changes, both gold: waiting for the FA
    final viewSwitch = CountTabs<bool>(
      tabs: [
        CountTab(
          value: false,
          label: 'New teams',
          count: countOf(ApprovalStatus.pending),
          highlight: true,
        ),
        CountTab(
          value: true,
          label: 'Changes',
          count: ref.watch(faChangesWaitingCountProvider),
          highlight: true,
        ),
      ],
      selected: _changes,
      onChanged: (changes) => setState(() => _changes = changes),
    );

    if (_changes) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                viewSwitch,
                const SizedBox(height: 16),
                // What the FA asked teams to correct (2.11b)
                const FaCorrectionsView(),
                const FaChangesView(),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              viewSwitch,
              const SizedBox(height: 12),
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
                    onTap: () =>
                        context.goKeepingHome(Routes.adminRequest(request.uid)),
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
///
/// Approved: the team as it is NOW (after any approved changes), with
/// "Previously …" when it was renamed (2.10c).
class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.onTap});

  final TeamRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final reason = request.rejectionReason;
    final when = request.updatedAt ?? request.createdAt;

    final current = request.status == ApprovalStatus.approved
        ? ref.watch(currentTeamProvider((
            teamId: teamNameKey(request.teamName),
            registeredName: request.teamName,
          )))
        : null;
    final team = current?.team;
    final name = team?.name ?? request.teamName;
    final previousName = current?.previousName;

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
                label: initialsFor(name),
                color: team?.logoColor ?? request.logoColor,
                url: team?.logoUrl ?? request.logoUrl,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${team?.shortName ?? request.shortName} · '
                      '${team?.town ?? request.town}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    CompetitionChips(
                      competitions: team?.categories ?? request.categories,
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
                  // Suspended by the chairman (2.11c, C3)
                  if (team?.isSuspended ?? false) ...[
                    const _SuspendedPill(),
                    const SizedBox(height: 6),
                  ],
                  if (previousName != null) ...[
                    PreviousNamePill(name: previousName),
                    const SizedBox(height: 6),
                  ],
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

/// Small red "Suspended" on an approved team's tile (2.11c).
class _SuspendedPill extends StatelessWidget {
  const _SuspendedPill();

  @override
  Widget build(BuildContext context) {
    final c = suspensionColours(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Suspended',
        style: TextStyle(
          color: c.ink,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
