import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/settings/data/app_version_provider.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

/// The "More" tab: account, appearance, league links, help, about, log out.
///
/// Written for any role. A team admin sees their team on the account card;
/// other roles see their own name.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GedfaAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AccountCard(),
                const SizedBox(height: 22),
                const _SectionTitle('Appearance'),
                const _AppearancePicker(),
                const SizedBox(height: 22),
                const _SectionTitle('League'),
                _TileGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Team profile',
                      subtitle: 'Logo, kits and officials',
                      onTap: () => _openComingSoon(
                        context,
                        title: 'Team profile',
                        icon: Icons.shield_outlined,
                        message: 'Soon you will see and update your logo, '
                            'kits and officials here.',
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.menu_book_outlined,
                      title: 'League rules',
                      subtitle: 'Squad size, registration, discipline',
                      onTap: () => _openComingSoon(
                        context,
                        title: 'League rules',
                        icon: Icons.menu_book_outlined,
                        message: 'The GEDFA league rules will be published '
                            'here once the FA confirms them.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionTitle('Help'),
                _TileGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & contact the FA',
                      subtitle: 'How to add players, phone and email',
                      onTap: () => _openComingSoon(
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

    final authUser = ref.watch(authStateProvider).value;
    final appUser = ref.watch(appUserProvider).value;
    final team = ref.watch(myTeamProvider).value;

    final name = team?.name ??
        appUser?.displayName ??
        authUser?.displayName ??
        'Your account';
    final role = appUser?.role;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          TeamLogo(
            label: initialsFor(name),
            color: team?.logoColor ?? AppColors.brandBlue,
            url: team?.logoUrl,
            size: 52,
          ),
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
                  authUser?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (role != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role.label.toUpperCase(),
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
        ],
      ),
    );
  }
}

// ── Appearance ───────────────────────────────────────────────────────────

class _AppearancePicker extends ConsumerWidget {
  const _AppearancePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('System'),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              ref.read(themeModeProvider.notifier).setMode(selection.first),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "System follows your phone's setting.",
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ── Building blocks ──────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
        ),
      ),
    );
  }
}

/// A rounded card holding rows, with a thin line between them.
class _TileGroup extends StatelessWidget {
  const _TileGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: scheme.outline),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      minTileHeight: 60,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: scheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
    );
  }
}

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

    return _SettingsTile(
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
      // No toast on success: the router moves straight to the login screen,
      // and this screen (with its toast) would vanish with it.
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

// ── Coming soon ──────────────────────────────────────────────────────────

/// Opens a simple placeholder page for a Settings row that isn't built yet.
/// It opens inside the More tab, so the bottom bar stays and Back returns
/// to Settings.
void _openComingSoon(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String message,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _ComingSoonPage(
        title: title,
        icon: icon,
        message: message,
      ),
    ),
  );
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GedfaAppBar(title: title),
      body: EmptyView(
        icon: icon,
        title: 'Coming soon',
        message: message,
      ),
    );
  }
}
