import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/count_tabs.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/position_rows.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';

/// FA: one team's juvenile players, by age group (2.14b, board J5).
///
/// U13 / U15 / U17 tabs with how many children are in each. Every child
/// shows the photo, date of birth and parent, which is what the FA needs
/// to prepare the screening day. The decision itself (pass / not
/// eligible) is made in More › Juvenile screening; tapping a card shows
/// the child's details.
class FaTeamJuvenileScreen extends ConsumerStatefulWidget {
  const FaTeamJuvenileScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<FaTeamJuvenileScreen> createState() =>
      _FaTeamJuvenileScreenState();
}

class _FaTeamJuvenileScreenState extends ConsumerState<FaTeamJuvenileScreen> {
  AgeGroup? _tab; // null = not chosen yet (picked from the data)

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamByIdProvider(widget.teamId));
    final playersAsync = ref.watch(juvenilePlayersProvider);
    final team = teamAsync.value;

    final children = sortedBySquadOrder(
      playersAsync.value?.where((p) => p.teamId == widget.teamId) ?? [],
    );
    final subtitle = team == null
        ? null
        : 'Juvenile · ${children.length} '
            '${children.length == 1 ? 'child' : 'children'}';

    Widget body;
    final error = teamAsync.error ?? playersAsync.error;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!teamAsync.hasValue || !playersAsync.hasValue) {
      body = const LoadingView();
    } else if (team == null) {
      body = const EmptyView(
        icon: Icons.search_off_rounded,
        title: 'Team not found',
        message: 'It may have been removed.',
      );
    } else {
      body = _body(children);
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: team?.name ?? 'Juvenile players',
        subtitle: subtitle,
        leading: BackButton(
          onPressed: () => context.goKeepingHome(Routes.adminPlayersJuvenile),
        ),
      ),
      body: body,
    );
  }

  Widget _body(List<Player> children) {
    int inGroup(AgeGroup g) => children.where((p) => p.ageGroup == g).length;
    int waitingIn(AgeGroup g) => children
        .where((p) => p.ageGroup == g && p.isWaitingForScreening)
        .length;

    // First visit: the first group with children waiting, else with
    // any children, else U13
    final tab = _tab ??
        AgeGroup.values.where((g) => waitingIn(g) > 0).firstOrNull ??
        AgeGroup.values.where((g) => inGroup(g) > 0).firstOrNull ??
        AgeGroup.u13;
    final shown = children.where((p) => p.ageGroup == tab).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CountTabs<AgeGroup>(
                tabs: [
                  for (final group in AgeGroup.values)
                    CountTab(
                      value: group,
                      label: group.label,
                      count: inGroup(group),
                      highlight: waitingIn(group) > 0,
                    ),
                ],
                selected: tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.child_care_outlined,
                    title: 'No ${tab.label} players',
                    message: 'Children appear here once the team adds them.',
                  ),
                )
              else
                for (final child in shown) ...[
                  _ChildCard(player: child),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One child: photo, name, number and position, date of birth with the
/// season age, "U13 age, in the U15 squad" when registered older, the
/// parent, and a status pill.
class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    final own = AgeGroup.ownGroup(player.dob);
    final group = player.ageGroup;
    final age = AgeGroup.seasonAge(player.dob);
    final year = Season.startYear(Season.current);
    final guardian = player.guardian;

    final (pillText, pillBg, pillInk) = switch (player.status) {
      ApprovalStatus.pending => (
          'Screening',
          isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC),
          isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700),
        ),
      ApprovalStatus.approved => (
          player.playerCode ?? 'Passed',
          isDark ? const Color(0xFF123D2B) : AppColors.approvedBg,
          isDark ? const Color(0xFF7BE3B0) : AppColors.approvedText,
        ),
      ApprovalStatus.rejected => (
          player.notEligible ? 'Not eligible' : 'To correct',
          isDark ? const Color(0xFF4A1820) : AppColors.rejectedBg,
          isDark ? const Color(0xFFFF9DA6) : AppColors.rejectedText,
        ),
    };

    // Tap: the child's details (Isaac, 3 Nov 2026)
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: () =>
            context.pushKeepingHome(Routes.adminJuvenileChild(player.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlayerAvatar(name: player.fullName, url: player.thumbUrl, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '#${player.jerseyNo} · ${player.position.code}',
                      style: muted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Born ${formatDate(player.dob)} · $age in $year',
                      style: textTheme.bodySmall,
                    ),
                    // Registered older than their age, e.g. a U13 in U15
                    if (own != null && group != null && own != group)
                      Text(
                        '${own.label} age, in the ${group.label} squad',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (guardian != null)
                      Text(
                        '${guardian.relation.label}: ${guardian.name} · '
                        '${guardian.phone}',
                        style: muted,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pillText,
                  style: TextStyle(
                    color: pillInk,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
