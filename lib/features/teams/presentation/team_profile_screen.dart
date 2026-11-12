import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_profile_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/change_status_note.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

/// Team: More › Team profile (2.10a, board P1).
///
/// Two cards:
/// - **Name and logo** (gold "FA approves"): name, short name, logo and
///   competitions. "Ask to change" sends a request to the FA (2.10b); a
///   gold note shows it is pending, red if the FA said no, green for a
///   week after it was approved.
/// - **Club details** (green "Saves straight away"): town, home ground,
///   colours, kits and officials. Each Edit opens its own screen; saving
///   tells the FA in the bell.
class TeamProfileScreen extends ConsumerWidget {
  const TeamProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(myTeamDetailsProvider);
    final changes = ref.watch(myTeamChangesProvider).value ?? const [];
    // Suspended (2.11c): no edits or change requests
    final suspended = ref.watch(myTeamProvider).value?.isSuspended ?? false;

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Team profile',
        subtitle: detailsAsync.value?.teamName,
        leading: const AppBackButton(fallback: Routes.teamMore),
      ),
      body: detailsAsync.when(
        loading: () => const LoadingView(message: 'Loading your team…'),
        error: (error, _) => ErrorView(
          message: appErrorMessage(error),
          onRetry: () => ref.invalidate(myTeamDetailsProvider),
        ),
        data: (team) => team == null
            ? const EmptyView(
                icon: Icons.shield_outlined,
                title: 'No team yet',
                message: 'Your team appears here once the FA approves it.',
              )
            : _Body(team: team, changes: changes, suspended: suspended),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.team,
    required this.changes,
    required this.suspended,
  });

  final TeamDetails team;
  final bool suspended;

  /// The team's requests to the FA (one of each kind at most)
  final List<TeamChange> changes;

  void _edit(BuildContext context, TeamSection section) {
    if (suspended) {
      AppToast.warning(context, suspendedMessage);
    } else {
      context.push(Routes.teamClubEdit(section.name));
    }
  }

  void _ask(BuildContext context, TeamChangeKind kind) {
    if (suspended) {
      AppToast.warning(context, suspendedMessage);
    } else {
      context.push(Routes.teamClubAsk(kind.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldBg = isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC);
    final goldInk = isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700);
    final okBg = isDark ? const Color(0xFF123D2B) : const Color(0xFFE3F2EA);
    final okInk = isDark ? const Color(0xFF7BE3B0) : const Color(0xFF00502F);

    final competitions = team.categories.length > 1
        ? 'Division and Juvenile'
        : team.categories.first.label;

    String slotsText(Iterable<KitSlot> slots) =>
        [for (final s in KitSlot.values) if (slots.contains(s)) _short(s)]
            .join(', ');
    final both = team.categories.length > 1;
    final firstKits = slotsText(team.divisionKits.keys);
    final juvenileKits = team.juvenileKits.isEmpty
        ? 'to add'
        : slotsText(team.juvenileKits.keys);
    final kitsText = both
        ? 'Division: $firstKits · Juvenile: $juvenileKits'
        : '${team.categories.first.label}: $firstKits';

    // Pending first, then the FA's latest answers
    final notes = changes.where(showsChangeNote).toList()
      ..sort((a, b) {
        if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
        final aTime = a.reviewedAt ?? a.createdAt ?? DateTime(0);
        final bTime = b.reviewedAt ?? b.createdAt ?? DateTime(0);
        return bTime.compareTo(aTime);
      });
    final toAdd = team.categories.contains(Competition.division)
        ? Competition.juvenile
        : Competition.division;

    final chairman = team.officialFor(OfficialRole.chairman) ??
        team.officialFor(OfficialRole.teamManager);
    final officialsText = [
      team.officials.length == 1
          ? '1 official'
          : '${team.officials.length} officials',
      if (chairman != null)
        '${chairman.name} (${chairman.roleText.toLowerCase()})',
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TeamLogo(
                  label: initialsFor(team.teamName),
                  color: team.logoColor,
                  url: team.logoUrl,
                  size: 84,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                team.teamName,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${team.shortName} · ${team.town} · $competitions',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              for (final change in notes) ...[
                ChangeStatusNote(change: change),
                const SizedBox(height: 14),
              ],
              _Card(
                title: 'Name and logo',
                tag: 'FA approves',
                tagBg: goldBg,
                tagInk: goldInk,
                rows: [
                  _Row(
                    label: 'Club name',
                    value: team.teamName,
                    onAsk: () => _ask(context, TeamChangeKind.name),
                  ),
                  _Row(
                    label: 'Short name',
                    value: team.shortName,
                    onAsk: () => _ask(context, TeamChangeKind.shortName),
                  ),
                  // Clubs in both: how the juvenile sides are called (JS3)
                  if (both)
                    _Row(
                      label: 'Juvenile side name',
                      value: team.juvenileSide.name,
                      note: team.hasOwnJuvenileName
                          ? '${team.juvenileSide.shortName} · U13, U15, U17'
                          : '"B" · U13, U15, U17',
                      onAsk: () => _ask(context, TeamChangeKind.juvenileName),
                    ),
                  _Row(
                    label: 'Logo',
                    value: '',
                    valueWidget: Align(
                      alignment: Alignment.centerLeft,
                      child: TeamLogo(
                        label: initialsFor(team.teamName),
                        color: team.logoColor,
                        url: team.logoUrl,
                        size: 36,
                      ),
                    ),
                    onAsk: () => _ask(context, TeamChangeKind.logo),
                  ),
                  _Row(
                    label: 'Competitions',
                    value: competitions,
                    note: both
                        ? 'Both competitions'
                        : team.categories.contains(Competition.division)
                            ? 'Juvenile brings screening and Juvenile kits'
                            : 'Division brings its own kits and players',
                    // Hidden for a club already in both
                    askLabel: 'Add ${toAdd.label}',
                    onAsk: both
                        ? null
                        : () => _ask(context, TeamChangeKind.competition),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Card(
                title: 'Club details',
                tag: 'Saves straight away',
                tagBg: okBg,
                tagInk: okInk,
                rows: [
                  _Row(
                    label: 'Town',
                    value: team.town,
                    onEdit: () => _edit(context, TeamSection.details),
                  ),
                  _Row(
                    label: 'Home ground',
                    value: team.homeGround,
                    note: team.homeGroundDirections,
                    onEdit: () => _edit(context, TeamSection.details),
                  ),
                  _Row(
                    label: 'Colours',
                    value: '',
                    valueWidget: _ColourDots(colours: team.colours),
                    onEdit: () => _edit(context, TeamSection.colours),
                  ),
                  _Row(
                    label: 'Kits',
                    value: kitsText,
                    onEdit: () => _edit(context, TeamSection.kits),
                  ),
                  _Row(
                    label: 'Officials',
                    value: officialsText,
                    onEdit: () => _edit(context, TeamSection.officials),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Changes to town, ground, colours, kits and officials '
                        'save straight away. The FA sees a note in the bell, '
                        'so nobody is surprised on match day.',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "home", "away", "GK"… for the Kits row
String _short(KitSlot slot) => switch (slot) {
      KitSlot.home => 'home',
      KitSlot.away => 'away',
      KitSlot.goalkeeper => 'GK',
      KitSlot.third => 'third',
      KitSlot.goalkeeper2 => 'GK 2',
    };

/// A card with a title, a coloured tag and rows.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.tag,
    required this.tagBg,
    required this.tagInk,
    required this.rows,
  });

  final String title;
  final String tag;
  final Color tagBg;
  final Color tagInk;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag.toUpperCase(),
                  style: TextStyle(
                    color: tagInk,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final row in rows) ...[
            Divider(height: 1, color: scheme.outline),
            row,
          ],
        ],
      ),
    );
  }
}

/// "Label   Value (note)   ✎ Edit", or "Ask to change ›" for what the FA
/// approves (2.10b).
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueWidget,
    this.note,
    this.onEdit,
    this.onAsk,
    this.askLabel = 'Ask to change',
  });

  final String label;
  final String value;
  final Widget? valueWidget;
  final String? note;
  final VoidCallback? onEdit;

  /// Opens "Ask the FA to change" (2.10b)
  final VoidCallback? onAsk;
  final String askLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final note = this.note;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                valueWidget ??
                    Text(
                      value,
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                if (note != null && note.trim().isNotEmpty)
                  Text(
                    note,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onEdit != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Edit',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (onAsk != null)
            Text(
              '$askLabel ›',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );

    final onTap = onEdit ?? onAsk;
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

/// ● ● Home · ● ● Away
class _ColourDots extends StatelessWidget {
  const _ColourDots({required this.colours});

  final TeamColours? colours;

  @override
  Widget build(BuildContext context) {
    final colours = this.colours;
    final textTheme = Theme.of(context).textTheme;
    if (colours == null) {
      return Text(
        'Not set yet',
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      );
    }

    Widget dot(Color color) => Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
        );

    final label =
        textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        dot(colours.home.main),
        dot(colours.home.second),
        Text(' Home  ·  ', style: label),
        dot(colours.away.main),
        dot(colours.away.second),
        Text(' Away', style: label),
      ],
    );
  }
}
