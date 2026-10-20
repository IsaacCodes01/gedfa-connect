import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/settings/data/data_saver_provider.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';

/// How the app behaves on this phone: appearance, data saver and (later)
/// notifications. Personal details live on My profile instead.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GedfaAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: const [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle('Appearance'),
                _AppearancePicker(),
                SizedBox(height: 24),
                SectionTitle('Mobile data'),
                _DataSaverTile(),
                SizedBox(height: 24),
                SectionTitle('Notifications'),
                _NotificationsPreview(),
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

// ── Data saver ───────────────────────────────────────────────────────────

class _DataSaverTile extends ConsumerWidget {
  const _DataSaverTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(dataSaverProvider);

    return TileGroup(
      children: [
        SwitchListTile(
          value: on,
          onChanged: (value) =>
              ref.read(dataSaverProvider.notifier).setOn(value),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          secondary: const TileIcon(Icons.data_saver_on_outlined),
          title: const Text(
            'Data saver',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            "Don't load player photos in lists; show initials instead. "
            'Opening a player still shows their photo.',
          ),
        ),
      ],
    );
  }
}

// ── Notifications (not built yet) ────────────────────────────────────────

class _NotificationsPreview extends StatelessWidget {
  const _NotificationsPreview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    const items = [
      ('Player approvals', 'Approved or rejected by the FA'),
      ('Fixtures', 'New and changed matches'),
      ('FA announcements', 'News from the district FA'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TileGroup(
          children: [
            for (final (title, subtitle) in items)
              SwitchListTile(
                value: false,
                onChanged: null, // greyed out until notifications exist
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(subtitle),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Coming with notifications. Until then, check the Squad tab.',
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
