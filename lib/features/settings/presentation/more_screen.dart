import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/settings/data/app_version_provider.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:go_router/go_router.dart';

/// The "More" tab: a menu. Your account card at the top (opens My profile),
/// then Team profile, Settings, league and help links, About and Log out.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GedfaAppBar(title: 'More'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AccountCard(),
                const SizedBox(height: 22),
                const SectionTitle('Team & app'),
                TileGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Team profile',
                      subtitle: 'Name, logo, kits and officials',
                      onTap: () => openComingSoon(
                        context,
                        title: 'Team profile',
                        icon: Icons.shield_outlined,
                        message: 'Soon you will see your team details here '
                            'and ask the FA to change the name or logo.',
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Appearance, data saver, notifications',
                      onTap: () => context.go(Routes.teamSettings),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionTitle('League & help'),
                TileGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.menu_book_outlined,
                      title: 'League rules',
                      subtitle: 'Squad size, registration, discipline',
                      onTap: () => openComingSoon(
                        context,
                        title: 'League rules',
                        icon: Icons.menu_book_outlined,
                        message: 'The GEDFA league rules will be published '
                            'here once the FA confirms them.',
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & contact the FA',
                      subtitle: 'How to add players, phone and email',
                      onTap: () => openComingSoon(
                        context,
                        title: 'Help & contact the FA',
                        icon: Icons.help_outline_rounded,
                        message: "Guides and the FA's contact details "
                            'are coming soon.',
                      ),
                    ),
                    const _AboutTile(),
                  ],
                ),
                const SizedBox(height: 28),
                const _LogOutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account card ─────────────────────────────────────────────────────────

class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final user = ref.watch(currentUserProvider).value;
    final appUser = ref.watch(appUserProvider).value;
    final team = ref.watch(myTeamProvider).value;

    final name = user?.displayName ?? appUser?.displayName ?? 'Your account';
    final role = appUser?.role;
    final roleLine = [
      if (role != null) role.label,
      if (team != null) team.name,
    ].join(' · ');

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: () => context.go(Routes.teamProfile),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              PersonAvatar(name: name, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      user?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (roleLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roleLine.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
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

/// A round avatar with a person's initials.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.size = 54});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

// ── About ────────────────────────────────────────────────────────────────

class _AboutTile extends ConsumerWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const district = 'Gomoa East District FA';
    final subtitle = ref.watch(appVersionProvider).when(
          data: (version) => 'Version $version · $district',
          loading: () => district,
          error: (_, _) => district,
        );

    return SettingsTile(
      icon: Icons.info_outline_rounded,
      title: 'About GEDFA Connect',
      subtitle: subtitle,
    );
  }
}

// ── Log out ──────────────────────────────────────────────────────────────

class _LogOutButton extends ConsumerWidget {
  const _LogOutButton();

  Future<void> _confirmAndLogOut(BuildContext context, WidgetRef ref) async {
    // Read the repository now: after the dialog the screen may be gone.
    final auth = ref.read(authRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _LogOutDialog(),
    );
    if (confirmed != true) return;

    try {
      await auth.signOut();
      // No toast on success: the router moves straight to the login screen.
    } catch (error) {
      if (context.mounted) AppToast.error(context, appErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: () => _confirmAndLogOut(context, ref),
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Log out'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error, width: 1.5),
      ),
    );
  }
}

class _LogOutDialog extends StatelessWidget {
  const _LogOutDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        "You'll need to log in again to use GEDFA Connect. "
        "Everything you've saved stays saved.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            // The app theme makes filled buttons full-width; not in a dialog.
            minimumSize: const Size(88, 44),
            backgroundColor: isDark ? const Color(0xFFC8283A) : scheme.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Log out'),
        ),
      ],
    );
  }
}
