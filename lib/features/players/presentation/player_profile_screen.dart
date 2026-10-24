import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/players/data/player_profile_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/player_profile.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:go_router/go_router.dart';

/// Team admin: one player's profile (Player profiles tab › tap a card).
class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({super.key, required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerProvider(playerId));
    final player = playerAsync.value;

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Player profile',
        actions: [
          if (player != null)
            TextButton.icon(
              onPressed: () =>
                  context.push(Routes.teamEditPlayerProfile(playerId)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
        ],
      ),
      body: playerAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (player) => player == null
            ? const EmptyView(
                icon: Icons.search_off_rounded,
                title: 'Player not found',
                message: 'They may have been removed.',
              )
            : _Body(player: player),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(teamProfilesProvider).value?[player.id] ??
        PlayerProfile.empty(player.id, player.teamId);
    final armbands = ref.watch(armbandsProvider(player.category.name)).value ??
        const Armbands();
    final badge = armbands.badgeFor(player.id);
    final code = player.playerCode;

    final statusText = switch (player.status) {
      ApprovalStatus.approved => 'Approved',
      ApprovalStatus.pending => 'Waiting for the FA',
      ApprovalStatus.rejected => 'Rejected by the FA',
    };

    Widget fact(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );

    Widget chip(String text, {bool main = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: main ? scheme.primary : null,
            borderRadius: BorderRadius.circular(999),
            border: main ? null : Border.all(color: scheme.outline),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: main ? FontWeight.w700 : FontWeight.w600,
              color: main ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        );

    final back = profile.expectedBack;
    final availabilityTitle = switch (profile.availability) {
      Availability.available => null,
      Availability.injured =>
        back == null ? 'Injured' : 'Injured · back around ${formatDate(back)}',
      Availability.unavailable => [
          'Unavailable',
          ?profile.unavailableReason?.label,
          if (back != null) 'back around ${formatDate(back)}',
        ].join(' · '),
    };
    final since = profile.availabilityAt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo, name, ID, armband, positions
              TileGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PassportPhoto(
                          name: player.fullName,
                          url: player.photoUrl,
                          width: 104,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.fullName,
                                style: textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '#${player.jerseyNo} · '
                                '${code == null ? '' : '$code · '}$statusText',
                                style: textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              if (badge != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.ghanaGold,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    badge == 'C' ? 'CAPTAIN' : 'VICE-CAPTAIN',
                                    style: const TextStyle(
                                      color: Color(0xFF3A2C00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  chip(player.position.code, main: true),
                                  for (final p in profile.otherPositions)
                                    chip('also ${p.code}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Injured / unavailable
              if (availabilityTitle != null) ...[
                const SizedBox(height: 14),
                InfoBox(
                  icon: profile.availability == Availability.injured
                      ? Icons.healing_outlined
                      : Icons.event_busy_outlined,
                  color: profile.availability == Availability.injured
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$availabilityTitle\n',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: "Can't be picked for team sheets until marked "
                              'available.'
                              '${since == null ? '' : ' Set on ${formatDate(since)}.'}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),
              Row(
                children: [
                  fact('${player.age}', 'Age'),
                  const SizedBox(width: 8),
                  fact(profile.heightText ?? '–', 'Height'),
                  const SizedBox(width: 8),
                  fact(
                    profile.weightKg == null ? '–' : '${profile.weightKg} kg',
                    'Weight',
                  ),
                  const SizedBox(width: 8),
                  fact(profile.foot?.label ?? '–', 'Foot'),
                ],
              ),

              if (profile.strengths.isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionTitle('Strengths'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in profile.strengths)
                      Chip(
                        label: Text(s.label),
                        backgroundColor: isDark
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFE3EEFA),
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 22),
              const SectionTitle('Football background'),
              TileGroup(
                children: [
                  DetailRow('Hometown', profile.hometown),
                  DetailRow('At the club since', profile.clubSince?.toString()),
                  DetailRow('Previous club', profile.previousClub),
                  DetailRow(
                    'Profile updated',
                    profile.updatedAt == null
                        ? null
                        : formatDate(profile.updatedAt!),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              const SectionTitle('This season'),
              TileGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (final label in const [
                              'Apps',
                              'Goals',
                              'Assists',
                              'Yellow',
                              'Red',
                            ])
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '–',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      label,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Filled in automatically from approved match '
                          'reports (Phases 4–5).',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              const SectionTitle('Private · team and FA only'),
              TileGroup(
                children: [
                  DetailRow(
                    'Emergency contact',
                    profile.emergencyName == null
                        ? null
                        : [
                            profile.emergencyName!,
                            ?profile.emergencyPhone,
                          ].join('\n'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
