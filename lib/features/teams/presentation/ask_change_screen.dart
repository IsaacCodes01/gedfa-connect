import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_profile_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/change_status_note.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/logo_picker.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:go_router/go_router.dart';

/// Team profile › "Ask the FA to change" (2.10b, board P2).
///
/// Pick what to change (club name, short name, logo, or add a
/// competition), fill in the new value and say why. Nothing changes
/// until the FA approves; one request of each kind at a time.
class AskChangeScreen extends ConsumerWidget {
  const AskChangeScreen({super.key, this.kind});

  /// The chip to start on ("Ask to change ›" on the Club name row = name)
  final TeamChangeKind? kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(myTeamDetailsProvider);
    final teamId = ref.watch(appUserProvider).value?.teamId;
    final team = detailsAsync.value;

    // Data first; the form copies it once and then keeps its own
    if (team == null || teamId == null) {
      return Scaffold(
        appBar: GedfaAppBar(
          title: 'Ask the FA to change',
          leading: const AppBackButton(fallback: Routes.teamClub),
        ),
        body: detailsAsync.hasError
            ? ErrorView(message: appErrorMessage(detailsAsync.error!))
            : const LoadingView(),
      );
    }
    return _Form(team: team, teamId: teamId, initialKind: kind);
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.team, required this.teamId, this.initialKind});

  final TeamDetails team;
  final String teamId;
  final TeamChangeKind? initialKind;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _reason = TextEditingController();

  late TeamChangeKind _kind = _kinds.contains(widget.initialKind)
      ? widget.initialKind!
      : TeamChangeKind.name;

  Uint8List? _logoBytes;
  String _logoType = 'image/jpeg';
  bool _addCompetition = true;
  bool _showErrors = false;
  bool _busy = false;

  TeamDetails get _team => widget.team;
  bool get _both => _team.categories.length > 1;

  /// A club already in both competitions has nothing to add.
  List<TeamChangeKind> get _kinds => [
        for (final kind in TeamChangeKind.values)
          if (kind != TeamChangeKind.competition || !_both) kind,
      ];

  /// Division-only adds Juvenile; Juvenile-only adds Division.
  Competition get _toAdd => _team.categories.contains(Competition.division)
      ? Competition.juvenile
      : Competition.division;

  @override
  void dispose() {
    _name.dispose();
    _shortName.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goBack(Routes.teamClub);
    }
  }

  /// The request of the chosen kind still waiting for the FA, if any.
  TeamChange? _pending(List<TeamChange> changes) => changes
      .where((change) => change.kind == _kind && change.isPending)
      .firstOrNull;

  /// What is missing, as a toast; null when ready to send.
  String? get _problem => switch (_kind) {
        TeamChangeKind.logo when _logoBytes == null =>
          'Choose the new logo first.',
        TeamChangeKind.competition when !_addCompetition =>
          'Tick "Add ${_toAdd.label}" to send the request.',
        _ => null,
      };

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    final formOk = _formKey.currentState!.validate();
    final problem = _problem;
    if (problem != null) {
      AppToast.warning(context, problem);
      return;
    }
    if (!formOk) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      final repository = ref.read(teamChangeRepositoryProvider);
      final to = switch (_kind) {
        TeamChangeKind.name => _name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        TeamChangeKind.shortName => _shortName.text.trim(),
        TeamChangeKind.competition => _toAdd.name,
        // The new logo goes up first; the request keeps its link
        TeamChangeKind.logo => await repository.uploadLogo(
            teamId: widget.teamId,
            bytes: _logoBytes!,
            contentType: _logoType,
          ),
      };
      await repository.ask(
        teamId: widget.teamId,
        team: _team,
        kind: _kind,
        to: to,
        reason: _reason.text.trim(),
        askedBy: user.uid,
        askedByName: user.displayName,
      );
      if (!mounted) return;
      AppToast.success(context, "Sent to the FA. You'll see the answer here.");
      _back();
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final changes = ref.watch(myTeamChangesProvider).value ?? const [];
    final pending = _pending(changes);
    final enabled = !_busy;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: GedfaAppBar(
          title: 'Ask the FA to change',
          subtitle: _team.teamName,
          leading: BackButton(onPressed: _busy ? null : _back),
        ),
        bottomNavigationBar: _SendBar(
          busy: _busy,
          // One request of each kind at a time
          onSend: pending == null ? _send : null,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'WHAT DO YOU WANT TO CHANGE?',
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final kind in _kinds)
                          _KindChip(
                            label: kind.chip,
                            selected: kind == _kind,
                            onTap: enabled
                                ? () => setState(() {
                                      _kind = kind;
                                      _showErrors = false;
                                    })
                                : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (pending != null)
                      ChangeStatusNote(change: pending)
                    else ...[
                      _card(enabled),
                      const SizedBox(height: 18),
                      Text(
                        'Why? (for the FA) *',
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reason,
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [LengthLimitingTextInputFormatter(300)],
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. The club merged with Fetteh Stars this season',
                        ),
                        // Same limits as the security rules (5 to 300)
                        validator: (value) => (value?.trim().length ?? 0) < 5
                            ? 'Tell the FA why (at least 5 characters)'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _InfoBox(
                      text: 'Until the FA decides, the old details are used '
                          'everywhere: fixtures, team sheets and the website. '
                          'You can ask for one change of each kind at a time.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The white card for the chosen kind: the value now and the new one.
  Widget _card(bool enabled) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget now(String label, String value) => Text.rich(
          TextSpan(children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ]),
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        );

    final content = switch (_kind) {
      TeamChangeKind.name => [
          now('Your club name now', _team.teamName),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            decoration: const InputDecoration(labelText: 'New club name'),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.length < 2) return 'Enter the new club name';
              if (name.toLowerCase() == _team.teamName.toLowerCase()) {
                return 'This is your name already';
              }
              return null;
            },
          ),
        ],
      TeamChangeKind.shortName => [
          now('Your short name now', _team.shortName),
          const SizedBox(height: 12),
          TextFormField(
            controller: _shortName,
            enabled: enabled,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
              LengthLimitingTextInputFormatter(4),
              _UpperCase(),
            ],
            decoration: const InputDecoration(
              labelText: 'New short name',
              helperText: '3 or 4 capital letters, e.g. GUSF',
            ),
            validator: (value) {
              final short = value?.trim() ?? '';
              if (!RegExp(r'^[A-Z]{3,4}$').hasMatch(short)) {
                return 'Use 3 or 4 capital letters';
              }
              if (short == _team.shortName) return 'This is your short name already';
              return null;
            },
          ),
        ],
      TeamChangeKind.logo => [
          Row(
            children: [
              Text(
                'Your logo now:',
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              TeamLogo(
                label: initialsFor(_team.teamName),
                color: _team.logoColor,
                url: _team.logoUrl,
                size: 36,
              ),
            ],
          ),
          const SizedBox(height: 14),
          LogoPicker(
            label: initialsFor(_team.teamName),
            color: _team.logoColor,
            bytes: _logoBytes,
            enabled: enabled,
            showError: _showErrors && _logoBytes == null,
            onPicked: (bytes, type) => setState(() {
              _logoBytes = bytes;
              _logoType = type;
            }),
            onRemoved: () => setState(() => _logoBytes = null),
          ),
        ],
      TeamChangeKind.competition => [
          now('You play in', _team.categories.first.label),
          const SizedBox(height: 12),
          _AddCompetitionBox(
            competition: _toAdd,
            checked: _addCompetition,
            onChanged: enabled
                ? (value) => setState(() => _addCompetition = value)
                : null,
          ),
        ],
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content,
      ),
    );
  }
}

/// A pill: filled deep blue when chosen, white with a border otherwise.
class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? scheme.primary : scheme.outline),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ☑ Add Juvenile (U13 / U15 / U17): what happens after approval.
class _AddCompetitionBox extends StatelessWidget {
  const _AddCompetitionBox({
    required this.competition,
    required this.checked,
    required this.onChanged,
  });

  final Competition competition;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final juvenile = competition == Competition.juvenile;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: checked ? scheme.primary : scheme.outline,
          width: checked ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onChanged == null ? null : () => onChanged!(!checked),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 14, 12),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: onChanged == null
                    ? null
                    : (value) => onChanged!(value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      juvenile
                          ? 'Add Juvenile (${Competition.juvenileAgeGroups.join(' / ')})'
                          : 'Add Division',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      juvenile
                          ? 'After approval: add Juvenile kits, then children '
                              'for screening'
                          : 'After approval: check your Division kits, then '
                              'add Division players',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The blue ⓘ box.
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// "Send to the FA" at the bottom. Null [onSend] greys it out (a request
/// of this kind is already waiting).
class _SendBar extends StatelessWidget {
  const _SendBar({required this.busy, required this.onSend});

  final bool busy;
  final VoidCallback? onSend;

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
          // heightFactor: 1, or the bar would fill the screen
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FilledButton(
                onPressed: busy ? null : onSend,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Send to the FA'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Types the short name in capitals.
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
