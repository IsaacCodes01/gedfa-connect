import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/correction_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_correction_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_profile_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team_correction.dart';
import 'package:go_router/go_router.dart';

/// FA › an approved team › Club details › Edit (2.11a, mockup A2). For
/// misspellings and obvious mistakes: town, home ground, directions, year
/// founded and email. "Save correction" asks "What was wrong?" (A2b).
class FaCorrectDetailsScreen extends ConsumerWidget {
  const FaCorrectDetailsScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(teamDetailsProvider(teamId));
    final team = detailsAsync.value;

    // Data first; the form copies it once and then keeps its own
    if (team == null) {
      return Scaffold(
        appBar: GedfaAppBar(
          title: 'Correct club details',
          leading: const AppBackButton(fallback: Routes.admin),
        ),
        body: detailsAsync.hasError
            ? ErrorView(message: appErrorMessage(detailsAsync.error!))
            : detailsAsync.isLoading
                ? const LoadingView(message: 'Loading the team…')
                : const EmptyView(
                    icon: Icons.search_off_rounded,
                    title: 'Team not found',
                    message: 'It may have been removed.',
                  ),
      );
    }
    return _Form(teamId: teamId, team: team);
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.teamId, required this.team});

  final String teamId;
  final TeamDetails team;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

/// One text field of the form: its label, team field and value now.
typedef _Field = ({
  String label,
  String key,
  String? now,
  TextEditingController controller,
});

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  late final List<_Field> _fields = [
    _field('Town', 'town', widget.team.town),
    _field('Home ground', 'homeGround', widget.team.homeGround),
    _field('Directions', 'homeGroundDirections',
        widget.team.homeGroundDirections),
    _field('Year founded', 'yearFounded', widget.team.yearFounded?.toString()),
    _field('Club email', 'email', widget.team.email),
  ];

  _Field _field(String label, String key, String? now) => (
        label: label,
        key: key,
        now: now == null || now.trim().isEmpty ? null : now.trim(),
        controller: TextEditingController(text: now ?? ''),
      );

  _Field _byKey(String key) => _fields.firstWhere((f) => f.key == key);

  @override
  void dispose() {
    for (final field in _fields) {
      field.controller.dispose();
    }
    super.dispose();
  }

  String? _typed(_Field field) {
    final text = field.controller.text.trim();
    return text.isEmpty ? null : text;
  }

  List<_Field> get _changed =>
      [for (final field in _fields) if (_typed(field) != field.now) field];

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goBack(Routes.admin);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      AppToast.warning(context, 'Check the fields in red.');
      return;
    }
    final changed = _changed;
    if (changed.isEmpty) {
      AppToast.warning(context, 'Nothing has changed yet.');
      return;
    }

    final reason = await showCorrectionReasonSheet(
      context,
      teamName: widget.team.teamName,
      lines: [
        for (final field in changed)
          correctionLine(field.label, field.now, _typed(field)),
      ],
    );
    if (reason == null || !mounted) return;

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(teamCorrectionRepositoryProvider).correct(
            teamId: widget.teamId,
            teamName: widget.team.teamName,
            section: CorrectionSection.details,
            changes: {
              for (final field in changed)
                field.key: field.key == 'yearFounded'
                    ? int.tryParse(_typed(field) ?? '')
                    : _typed(field),
            },
            lines: [
              for (final field in changed)
                correctionLine(field.label, field.now, _typed(field)),
            ],
            reason: reason,
            faUid: user.uid,
            faName: user.displayName,
          );
      if (!mounted) return;
      AppToast.success(
        context,
        'Corrected. ${widget.team.teamName} has been told.',
      );
      _back();
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String? _yearValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    if (year == null || year < 1900 || year > DateTime.now().year) {
      return 'Enter a real year';
    }
    return null;
  }

  static String? _optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return Validators.email(value);
  }

  /// A text field, with "Was: …" under it once it differs.
  Widget _input(
    String key, {
    String? Function(String?)? validator,
    int maxLength = 80,
    int minLines = 1,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.words,
    List<TextInputFormatter> formatters = const [],
    String? helperText,
  }) {
    final field = _byKey(key);
    final changed = _typed(field) != field.now;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: field.controller,
            enabled: !_busy,
            minLines: minLines,
            maxLines: minLines == 1 ? 1 : minLines + 1,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            inputFormatters: [
              ...formatters,
              LengthLimitingTextInputFormatter(maxLength),
            ],
            decoration: InputDecoration(
              labelText: field.label,
              helperText: helperText,
              alignLabelWithHint: minLines > 1,
            ),
            onChanged: (_) => setState(() {}),
            validator: validator,
          ),
          if (changed) ...[
            const SizedBox(height: 6),
            WasLine(field.now),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: GedfaAppBar(
          title: 'Correct club details',
          subtitle: widget.team.teamName,
          leading: CloseButton(onPressed: _busy ? null : _back),
        ),
        bottomNavigationBar: _SaveBar(busy: _busy, onSave: _save),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 18, color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${widget.team.teamName} will see this change '
                              'and your reason in their bell.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _input(
                      'town',
                      maxLength: 60,
                      validator: (value) =>
                          Validators.requiredField(value, 'the town'),
                    ),
                    _input(
                      'homeGround',
                      validator: (value) =>
                          Validators.requiredField(value, 'the home ground'),
                    ),
                    _input(
                      'homeGroundDirections',
                      maxLength: 300,
                      minLines: 2,
                      capitalization: TextCapitalization.sentences,
                      helperText: 'Optional',
                    ),
                    _input(
                      'yearFounded',
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _yearValidator,
                      helperText: 'Optional',
                    ),
                    _input(
                      'email',
                      maxLength: 120,
                      keyboardType: TextInputType.emailAddress,
                      capitalization: TextCapitalization.none,
                      validator: _optionalEmail,
                      helperText: 'Optional',
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

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.busy, required this.onSave});

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
          // heightFactor: 1, or the bar would fill the screen
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FilledButton(
                onPressed: busy ? null : onSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Save correction'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
