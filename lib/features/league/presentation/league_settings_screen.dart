import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:go_router/go_router.dart';

/// Board L1: FA › More › League settings. Registration switches (any FA
/// official), squad numbers, and the season, fee and MoMo number (the
/// chairman only). Every change is kept in the history with who made it.
class LeagueSettingsScreen extends ConsumerStatefulWidget {
  const LeagueSettingsScreen({super.key});

  @override
  ConsumerState<LeagueSettingsScreen> createState() =>
      _LeagueSettingsScreenState();
}

class _LeagueSettingsScreenState extends ConsumerState<LeagueSettingsScreen> {
  /// What the FA is changing; null until they change something.
  LeagueSettings? _draft;
  bool _busy = false;

  Future<void> _save(LeagueSettings saved) async {
    final draft = _draft;
    final me = ref.read(appUserProvider).value;
    if (draft == null || me == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(leagueSettingsRepositoryProvider)
          .save(draft, before: saved, by: me);
      if (!mounted) return;
      AppToast.success(context, 'League settings saved.');
      setState(() => _draft = null);
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The pencil on season, fee and MoMo number (chairman only).
  Future<void> _editText({
    required String title,
    required String initial,
    required String? Function(String) validate,
    required void Function(String) apply,
    TextInputType keyboard = TextInputType.text,
    String? hint,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: title,
        initial: initial,
        validate: validate,
        keyboard: keyboard,
        hint: hint,
      ),
    );
    if (value != null && mounted) setState(() => apply(value));
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(leagueSettingsProvider);
    final isChairman = ref.watch(appUserProvider).value?.isChairman ?? false;

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'League settings',
        subtitle: 'District FA · More',
        leading: BackButton(onPressed: () => context.go(Routes.adminMore)),
      ),
      body: settingsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (saved) {
          final s = _draft ?? saved;
          void change(LeagueSettings next) => setState(() => _draft = next);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  ResponsiveCenter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionTitle('Registration'),
                        TileGroup(
                          children: [
                            _Switch(
                              title: 'New teams can register',
                              on: s.teamRegistrationOpen,
                              onText: 'Open: clubs can send a registration',
                              offText:
                                  'Closed: "Register your team" is hidden',
                              onChanged: (v) => change(
                                s.copyWith(teamRegistrationOpen: v),
                              ),
                            ),
                            _Switch(
                              title: 'Teams can add players',
                              on: s.playerRegistrationOpen,
                              onText: 'Open: teams can add new players',
                              offText: 'Closed: "Add player" is hidden',
                              onChanged: (v) => change(
                                s.copyWith(playerRegistrationOpen: v),
                              ),
                            ),
                          ],
                        ),
                        const _Hint(
                          'When closed, the buttons are hidden and the '
                          'security rules refuse new registrations. Players '
                          'already sent can still be reviewed and corrected. '
                          'Every official sees a note in the bell when '
                          'registration opens or closes.',
                        ),
                        const SizedBox(height: 18),
                        const SectionTitle('Squad numbers'),
                        TileGroup(
                          children: [
                            _Stepper(
                              title: 'Squad size',
                              subtitle: 'Most players per competition',
                              value: s.maxSquadSize,
                              min: 11,
                              max: 40,
                              onChanged: (v) =>
                                  change(s.copyWith(maxSquadSize: v)),
                            ),
                            _Stepper(
                              title: 'Matchday squad',
                              subtitle: 'Starting 11 + substitutes',
                              value: s.matchdaySquad,
                              min: 11,
                              max: 23,
                              onChanged: (v) =>
                                  change(s.copyWith(matchdaySquad: v)),
                            ),
                            _Stepper(
                              title: 'Substitutes allowed',
                              subtitle: 'Changes during a match',
                              value: s.matchdaySubs,
                              min: 0,
                              max: 12,
                              onChanged: (v) =>
                                  change(s.copyWith(matchdaySubs: v)),
                            ),
                            _Stepper(
                              title: 'Fewest players to start',
                              subtitle: 'The team sheet stays red until then',
                              value: s.minPlayers,
                              min: 7,
                              max: 11,
                              onChanged: (v) =>
                                  change(s.copyWith(minPlayers: v)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const SectionTitle('Season and fee'),
                        TileGroup(
                          children: [
                            _ValueRow(
                              label: 'Season',
                              value: Season.label(s.season),
                              canEdit: isChairman,
                              onEdit: () => _editText(
                                title: 'Season',
                                initial: Season.label(s.season),
                                hint: 'e.g. 2027/28',
                                validate: (v) => RegExp(r'^20\d{2}/\d{2}$')
                                        .hasMatch(v.trim())
                                    ? null
                                    : 'Write it like 2027/28',
                                apply: (v) => _draft = s.copyWith(
                                  season: v.trim().replaceAll('/', '-'),
                                ),
                              ),
                            ),
                            _ValueRow(
                              label: 'Affiliation fee',
                              value: cedis(s.fee),
                              canEdit: isChairman,
                              onEdit: () => _editText(
                                title: 'Affiliation fee (GH₵)',
                                initial: '${s.fee}',
                                keyboard: TextInputType.number,
                                validate: (v) {
                                  final n = int.tryParse(v.trim());
                                  return n == null || n < 1 || n > 100000
                                      ? 'Enter an amount in cedis'
                                      : null;
                                },
                                apply: (v) => _draft =
                                    s.copyWith(fee: int.parse(v.trim())),
                              ),
                            ),
                            _ValueRow(
                              label: 'MoMo number',
                              value: s.momoNumber,
                              canEdit: isChairman,
                              onEdit: () => _editText(
                                title: 'MoMo number',
                                initial: s.momoNumber,
                                keyboard: TextInputType.phone,
                                hint: 'e.g. 024 123 4567',
                                validate: (v) =>
                                    v.trim().length < 4 || v.trim().length > 20
                                        ? 'Enter the MoMo number'
                                        : null,
                                apply: (v) =>
                                    _draft = s.copyWith(momoNumber: v.trim()),
                              ),
                            ),
                          ],
                        ),
                        if (!isChairman)
                          const _Hint(
                            'Only the chairman can change the season, the '
                            'fee and the MoMo number.',
                          )
                        else
                          const _Hint(
                            'A new season starts a new fee for every team. '
                            'Change it only when the new season begins.',
                          ),
                        const SizedBox(height: 18),
                        const SectionTitle('League table'),
                        const TileGroup(
                          children: [
                            ListTile(
                              title: Text(
                                'Tie-breakers: as the Premier League',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Points, then goal difference, goals scored, '
                                'head-to-head. Used in Phase 4.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const SectionTitle('Recent changes'),
                        const _History(),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _SaveBar(
                  dirty: _draft != null &&
                      _draft!.changesFrom(saved).isNotEmpty,
                  busy: _busy,
                  onSave: () => _save(saved),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.title,
    required this.on,
    required this.onText,
    required this.offText,
    required this.onChanged,
  });

  final String title;
  final bool on;
  final String onText;
  final String offText;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: on,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(on ? onText : offText),
    );
  }
}

/// "Squad size   [−] 30 [+]"
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget button(IconData icon, String tip, int? next) => IconButton.outlined(
          tooltip: tip,
          onPressed: next == null ? null : () => onChanged(next),
          icon: Icon(icon),
          style: IconButton.styleFrom(
            side: BorderSide(color: scheme.outline, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  subtitle,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          button(Icons.remove_rounded, 'Fewer', value > min ? value - 1 : null),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          button(Icons.add_rounded, 'More', value < max ? value + 1 : null),
        ],
      ),
    );
  }
}

/// "Affiliation fee   GH₵ 1,000  ✎" (a lock when not the chairman).
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    required this.canEdit,
    required this.onEdit,
  });

  final String label;
  final String value;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: canEdit ? onEdit : null,
      title: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Icon(
            canEdit ? Icons.edit_outlined : Icons.lock_outline_rounded,
            size: 18,
            color: canEdit ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// The last changes: who, when, what. So nobody can quietly open
/// registration for a friend.
class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final history = ref.watch(settingsHistoryProvider).value ?? const [];

    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'No changes yet.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return TileGroup(
      children: [
        for (final entry in history)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    entry.byName,
                    if (entry.at case final at?) formatDateTime(at),
                  ].join(' · '),
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                for (final line in entry.changes)
                  Text(line, style: textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.busy,
    required this.onSave,
  });

  final bool dirty;
  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FilledButton(
                onPressed: dirty && !busy ? onSave : null,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(dirty ? 'Save changes' : 'No changes'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.validate,
    required this.keyboard,
    this.hint,
  });

  final String title;
  final String initial;
  final String? Function(String) validate;
  final TextInputType keyboard;
  final String? hint;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: widget.keyboard,
          inputFormatters: widget.keyboard == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(hintText: widget.hint),
          validator: (v) => widget.validate(v ?? ''),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_controller.text);
          },
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
