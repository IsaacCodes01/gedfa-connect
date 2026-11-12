import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/suspensions/data/player_suspension_repository.dart';
import 'package:gedfa_connect/features/suspensions/domain/player_suspension.dart';
import 'package:gedfa_connect/features/suspensions/presentation/widgets/ban_widgets.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// SP2 (3.1e1): FA › Players › Suspended. Everyone suspended now, by
/// competition: club, reason, matches left, the return match, and Lift.
class SuspendedPlayersScreen extends ConsumerWidget {
  const SuspendedPlayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suspensions = ref.watch(seasonSuspensionsProvider);
    final fixtures = ref.watch(seasonFixturesProvider);
    final bans = ref.watch(faBansProvider).values.toList()
      ..sort((a, b) {
        final byTeam = a.suspension.teamName.compareTo(b.suspension.teamName);
        return byTeam != 0
            ? byTeam
            : a.suspension.playerName.compareTo(b.suspension.playerName);
      });
    final error = suspensions.error ?? fixtures.error;

    final Widget body;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!suspensions.hasValue || !fixtures.hasValue) {
      body = const SkeletonList(message: 'Getting suspended players…');
    } else if (bans.isEmpty) {
      body = const EmptyView(
        icon: Icons.verified_user_outlined,
        title: 'Nobody is suspended',
        message:
            "Suspend a player from their page (Players › a team › the "
            'player).',
      );
    } else {
      final division = [
        for (final b in bans)
          if (b.suspension.competition.category == Competition.division) b,
      ];
      final juvenile = [
        for (final b in bans)
          if (b.suspension.competition.category == Competition.juvenile) b,
      ];
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          ResponsiveCenter(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (title, list) in [
                  ('Division', division),
                  ('Juvenile', juvenile),
                ])
                  if (list.isNotEmpty) ...[
                    _Heading(title: title, count: list.length),
                    _Group(bans: list),
                    const SizedBox(height: 14),
                  ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'Lift ends it early (with a reason, e.g. an appeal won). '
                    'A suspension ends by itself after its last missed match.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Suspended players',
        subtitle: 'Season ${Season.label(Season.current)} · ${bans.length} now',
        leading: AppBackButton(fallback: Routes.adminPlayers),
      ),
      body: body,
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count',
            style: textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.bans});

  final List<BanStatus> bans;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkCardBorder : AppColors.cardBorder;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          for (final (i, ban) in bans.indexed) ...[
            if (i > 0) Divider(height: 1, color: border),
            _BanRow(ban: ban),
          ],
        ],
      ),
    );
  }
}

/// Photo, name, "Club · Reason", the matches left, "Returns …", Lift.
class _BanRow extends ConsumerWidget {
  const _BanRow({required this.ban});

  final BanStatus ban;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ban.suspension;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (redBg, redInk) = banColours(context);
    final player = ref.watch(playerProvider(s.playerId)).value;
    final back = ban.returnMatch;
    final when = back?.kickoffAt;
    final returns = back == null || when == null
        ? (ban.notInCalendar > 0
              ? 'Returns after matches not in the calendar yet'
              : 'Returns for the next match')
        : 'Returns ${formatShortDate(when)} v ${back.opponentOf(s.teamId).name}';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      // A child (also one banned in the Division) opens the child's page
      onTap: () => context.open(
        (player?.isJuvenile ?? s.competition.category == Competition.juvenile)
            ? Routes.adminJuvenileChild(s.playerId)
            : Routes.adminPlayer(s.playerId),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          children: [
            PassportPhoto(
              name: s.playerName,
              url: player?.thumbUrl ?? player?.photoUrl,
              width: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 5,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${s.teamName} · ${s.reasonLabel} ·',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: redBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          ban.leftText,
                          style: TextStyle(
                            color: redInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    returns,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => liftBan(context, ref, s),
              child: const Text('Lift'),
            ),
          ],
        ),
      ),
    );
  }
}
