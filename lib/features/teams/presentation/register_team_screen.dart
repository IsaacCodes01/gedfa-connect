import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/connectivity/connectivity_provider.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/files/picked_document.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/short_name.dart';
import 'package:gedfa_connect/core/utils/team_name_key.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/club_status.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:gedfa_connect/features/teams/presentation/kit_editor_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/club_status_step.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/club_step.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/kits_step.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/officials_step.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/review_step.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/officials_editor.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// The steps in order (2.13: officials before kits). The last one,
/// Review & submit, is not counted in "Step 2 of 4".
const _stepTitles = [
  'Club details',
  'Club status',
  'Officials',
  'Kits',
  'Review & submit',
];
const _countedSteps = 4;

// Step numbers, so the code reads clearly
const _clubStep = 0;
const _statusStep = 1;
const _officialsStep = 2;
const _kitsStep = 3;

class RegisterTeamScreen extends ConsumerStatefulWidget {
  const RegisterTeamScreen({super.key});

  @override
  ConsumerState<RegisterTeamScreen> createState() =>
      _RegisterTeamScreenState();
}

class _RegisterTeamScreenState extends ConsumerState<RegisterTeamScreen> {
  int _step = 0;
  bool _busy = false;
  bool _editingFromReview = false;
  bool _checking = false; // checking the team name online (Next button only)
  bool _forward = true;   // which way the step slides
  final Set<int> _showErrors = {};

  final _clubFormKey = GlobalKey<FormState>();
  final _statusFormKey = GlobalKey<FormState>();

  // Step 1: club details
  final _teamName = TextEditingController();
  final _shortName = TextEditingController();
  final _town = TextEditingController();
  final _homeGround = TextEditingController();
  final _directions = TextEditingController();
  final _yearFounded = TextEditingController();
  final _email = TextEditingController();
  bool _shortNameEdited = false;
  String? _nameTakenError;
  Uint8List? _logoBytes;
  String _logoType = 'image/jpeg';

  // Step 2: club status (2.13)
  ClubStatus _clubStatus = ClubStatus.existing;
  final _lastLeague = TextEditingController();
  PickedDocument? _letter;
  PickedDocument? _licence;

  // Step 3: officials
  late final List<OfficialDraft> _officials;

  // Step 4: kits
  final Map<KitSlot, Kit?> _kits = {
    for (final slot in KitSlot.values) slot: null,
  };

  // Review: declaration
  bool _agreed = false;

  // Competitions (step 1)
  Set<Competition> _competitions = {Competition.division};

  // Editing an existing request: the files already uploaded
  TeamRequest? _existing;
  String? _existingLogoUrl;
  String? _existingLetterUrl;
  String? _existingLicenceUrl;
  bool _existingLicenceIsPdf = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(myTeamRequestProvider).value;

    if (existing != null && existing.canEdit) {
      _existing = existing;
      _teamName.text = existing.teamName;
      _shortName.text = existing.shortName;
      _town.text = existing.town;
      _homeGround.text = existing.homeGround;
      _directions.text = existing.homeGroundDirections ?? '';
      _yearFounded.text = existing.yearFounded?.toString() ?? '';
      _email.text = existing.email ?? '';
      _shortNameEdited = true;
      _existingLogoUrl = existing.logoUrl;
      _competitions = {...existing.categories};
      _clubStatus = existing.clubStatus;
      _lastLeague.text = existing.lastLeague ?? '';
      _existingLetterUrl = existing.letterUrl;
      _existingLicenceUrl = existing.licenceUrl;
      _existingLicenceIsPdf = existing.licenceIsPdf;
      _kits[KitSlot.home] = existing.homeKit;
      _kits[KitSlot.away] = existing.awayKit;
      _kits[KitSlot.goalkeeper] = existing.goalkeeperKit;
      _kits[KitSlot.third] = existing.thirdKit;
      _kits[KitSlot.goalkeeper2] = existing.goalkeeperKit2;
      _officials =
          existing.officials.map(OfficialDraft.fromOfficial).toList();
    } else {
      final myName = ref.read(authStateProvider).value?.displayName ?? '';
      _officials = [
        OfficialDraft(OfficialRole.teamManager, name: myName),
        OfficialDraft(OfficialRole.headCoach),
      ];
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _teamName,
      _shortName,
      _town,
      _homeGround,
      _directions,
      _yearFounded,
      _email,
      _lastLeague,
    ]) {
      controller.dispose();
    }
    for (final draft in _officials) {
      draft.dispose();
    }
    super.dispose();
  }

  bool get _isOnline => switch (ref.read(isOnlineProvider)) {
        AsyncData(:final value) => value,
        _ => true,
      };

  Color get _logoColor =>
      _kits[KitSlot.home]?.primary ?? AppColors.brandBlue;

  // ---------- Step 1 helpers ----------

  void _onTeamNameChanged(String value) {
    setState(() {
      _nameTakenError = null;
      if (!_shortNameEdited) _shortName.text = suggestShortName(value);
    });
  }

  String? _validateTeamName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter the team name';
    if (teamNameKey(name).length < 2) return 'The team name is too short';
    if (name.length > 60) return 'Keep the team name under 60 characters';
    return _nameTakenError;
  }

  Future<bool> _isNameAvailable() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return false;
    try {
      final available = await ref
          .read(teamRequestRepositoryProvider)
          .isNameAvailable(_teamName.text, uid: uid);
      if (!available && mounted) {
        setState(() => _nameTakenError = 'Another team already uses this name');
        _clubFormKey.currentState?.validate();
      }
      return available;
    } catch (_) {
      // Can't check right now (e.g. offline). Submit checks again.
      return true;
    }
  }

  bool get _hasLogo =>
      _logoBytes != null || (_existingLogoUrl ?? '').isNotEmpty;

  // ---------- Step 2 helpers (club status) ----------

  bool get _hasLetter => _letter != null || _existingLetterUrl != null;

  Future<void> _pickLetter() async {
    final file = await pickDocument(context, allowPhoto: false);
    if (file != null && mounted) setState(() => _letter = file);
  }

  Future<void> _pickLicence() async {
    final file = await pickDocument(context, allowPhoto: true);
    if (file != null && mounted) setState(() => _licence = file);
  }

  void _removeLicence() => setState(() {
        _licence = null;
        _existingLicenceUrl = null;
      });

  // ---------- Step 3 helpers (officials) ----------

  void _addOfficial(OfficialDraft draft) {
    setState(() {
      _officials
        ..add(draft)
        // Same order as the list of roles; "Other" ones stay last
        ..sort((a, b) => a.role.index.compareTo(b.role.index));
    });
  }

  void _removeOfficial(OfficialDraft draft) {
    setState(() => _officials.remove(draft));
    draft.dispose();
  }

  // ---------- Step 4 helpers (kits) ----------

  Future<void> _editKit(KitSlot slot) async {
    final result = await KitEditorScreen.open(
      context,
      title: slot.label,
      initial: _kits[slot],
    );
    if (result != null && mounted) setState(() => _kits[slot] = result);
  }

  // ---------- Navigation ----------

  Future<bool> _validateCurrentStep() async {
    switch (_step) {
      case _clubStep:
        final fieldsOk = _clubFormKey.currentState!.validate();
        if (!fieldsOk || !_hasLogo) return false;
        return _isNameAvailable();
      case _statusStep:
        final fieldsOk = _statusFormKey.currentState!.validate();
        return fieldsOk &&
            (_clubStatus == ClubStatus.existing || _hasLetter);
      case _officialsStep:
        return _officials.every((draft) => draft.isComplete);
      case _kitsStep:
        return KitSlot.values
            .where((slot) => slot.isRequired)
            .every((slot) => _kits[slot] != null);
      default:
        return true;
    }
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();

    // Only step 1 waits for the internet (team name check).
    // The other steps check instantly, so nothing turns grey.
    if (_step == _clubStep) setState(() => _checking = true);
    final ok = await _validateCurrentStep();
    if (!mounted) return;
    if (_step == _clubStep) setState(() => _checking = false);

    if (!ok) {
      setState(() => _showErrors.add(_step));
      AppToast.warning(context, switch (_step) {
        _clubStep when !_hasLogo => 'Add your team logo to continue.',
        _statusStep when _clubStatus == ClubStatus.newClub && !_hasLetter =>
          'Upload your letter to the chairman to continue.',
        _officialsStep =>
          'Add the name and phone of every official (tap a row).',
        _kitsStep => 'Set the home, away and goalkeeper kits to continue.',
        _ => 'Please fix the highlighted fields.',
      });
      return;
    }
    setState(() {
      _forward = true;
      if (_editingFromReview) {
        _editingFromReview = false;
        _step = _stepTitles.length - 1;
      } else {
        _step++;
      }
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_editingFromReview) {
      _next();
    } else if (_step == _clubStep) {
      context.go(Routes.welcome);
    } else {
      setState(() {
        _forward = false;
        _step--;
      });
    }
  }

  // ---------- Submit ----------

  TeamRequest _buildRequest(
    String uid, {
    required String? logoUrl,
    required String? letterUrl,
    required String? licenceUrl,
    required bool licenceIsPdf,
  }) {
    return TeamRequest(
      uid: uid,
      teamName: _teamName.text,
      shortName: _shortName.text,
      town: _town.text,
      homeGround: _homeGround.text,
      homeGroundDirections: _directions.text,
      yearFounded: int.tryParse(_yearFounded.text.trim()),
      email: _email.text,
      logoUrl: logoUrl,
      categories: _competitions,
      clubStatus: _clubStatus,
      lastLeague: _lastLeague.text,
      letterUrl: letterUrl,
      licenceUrl: licenceUrl,
      licenceIsPdf: licenceIsPdf,
      homeKit: _kits[KitSlot.home]!,
      awayKit: _kits[KitSlot.away]!,
      goalkeeperKit: _kits[KitSlot.goalkeeper]!,
      thirdKit: _kits[KitSlot.third],
      goalkeeperKit2: _kits[KitSlot.goalkeeper2],
      officials: _officials.map((draft) => draft.toOfficial()).toList(),
      status: ApprovalStatus.pending,
    );
  }

  Future<void> _submit() async {
    if (!_agreed) {
      AppToast.warning(context, 'Tick the declaration to submit.');
      return;
    }
    if (!_isOnline) {
      AppToast.warning(
        context,
        "You're offline. Connect to the internet to submit.",
      );
      return;
    }
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      final repository = ref.read(teamRequestRepositoryProvider);

      String? logoUrl = _existingLogoUrl;
      final logo = _logoBytes;
      if (logo != null) {
        logoUrl = await repository.uploadLogo(
          uid: uid,
          bytes: logo,
          contentType: _logoType,
        );
      }

      // The letter only matters for a new club
      String? letterUrl;
      if (_clubStatus == ClubStatus.newClub) {
        letterUrl = _existingLetterUrl;
        final letter = _letter;
        if (letter != null) {
          letterUrl = await repository.uploadFile(
            uid: uid,
            fileName: 'letter.pdf',
            bytes: letter.bytes,
            contentType: letter.contentType,
          );
        }
      }

      String? licenceUrl = _existingLicenceUrl;
      var licenceIsPdf = _existingLicenceIsPdf;
      final licence = _licence;
      if (licence != null) {
        licenceUrl = await repository.uploadFile(
          uid: uid,
          fileName: licence.isPdf ? 'licence.pdf' : 'licence.jpg',
          bytes: licence.bytes,
          contentType: licence.contentType,
        );
        licenceIsPdf = licence.isPdf;
      }

      final request = _buildRequest(
        uid,
        logoUrl: logoUrl,
        letterUrl: letterUrl,
        licenceUrl: licenceUrl,
        licenceIsPdf: licenceIsPdf,
      );
      final existing = _existing;
      if (existing == null) {
        await repository.create(request);
      } else {
        await repository.update(
          request,
          previousNameKey: teamNameKey(existing.teamName),
        );
      }

      if (!mounted) return;
      AppToast.success(
        context,
        existing == null
            ? 'Registration sent! The FA will review it soon.'
            : 'Changes sent. The FA will review them.',
      );
      context.go(Routes.welcome);
    } on TeamNameTakenException {
      if (!mounted) return;
      setState(() {
        _nameTakenError = 'Another team already uses this name';
        _showErrors.add(_clubStep);
        _step = _clubStep;
      });
      AppToast.error(context, appErrorMessage(const TeamNameTakenException()));
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Build ----------

  Widget _buildStep() {
    final enabled = !_busy;
    return switch (_step) {
      _clubStep => ClubStep(
          formKey: _clubFormKey,
          showErrors: _showErrors.contains(_clubStep),
          enabled: enabled,
          teamName: _teamName,
          shortName: _shortName,
          town: _town,
          homeGround: _homeGround,
          directions: _directions,
          yearFounded: _yearFounded,
          email: _email,
          logoBytes: _logoBytes,
          logoColor: _logoColor,
          teamNameValidator: _validateTeamName,
          onTeamNameChanged: _onTeamNameChanged,
          onShortNameEdited: () => _shortNameEdited = true,
          onLogoPicked: (bytes, type) => setState(() {
            _logoBytes = bytes;
            _logoType = type;
          }),
          logoUrl: _existingLogoUrl,
          onLogoRemoved: () => setState(() {
            _logoBytes = null;
            _existingLogoUrl = null;
          }),
          competitions: _competitions,
          onCompetitionsChanged: (value) =>
              setState(() => _competitions = value),
        ),
      _statusStep => ClubStatusStep(
          formKey: _statusFormKey,
          showErrors: _showErrors.contains(_statusStep),
          enabled: enabled,
          status: _clubStatus,
          onStatusChanged: (value) => setState(() => _clubStatus = value),
          lastLeague: _lastLeague,
          letter: _letter,
          letterUrl: _existingLetterUrl,
          onPickLetter: _pickLetter,
          licence: _licence,
          licenceUrl: _existingLicenceUrl,
          licenceIsPdf: _existingLicenceIsPdf,
          onPickLicence: _pickLicence,
          onRemoveLicence: _removeLicence,
        ),
      _officialsStep => OfficialsStep(
          showErrors: _showErrors.contains(_officialsStep),
          enabled: enabled,
          drafts: _officials,
          onAdd: _addOfficial,
          onRemove: _removeOfficial,
          onChanged: () => setState(() {}),
        ),
      _kitsStep => KitsStep(
          kits: _kits,
          showErrors: _showErrors.contains(_kitsStep),
          enabled: enabled,
          onEdit: _editKit,
          onRemove: (slot) => setState(() => _kits[slot] = null),
        ),
      _ => ReviewStep(
          teamName: _teamName.text.trim(),
          shortName: _shortName.text.trim().toUpperCase(),
          town: _town.text.trim(),
          homeGround: _homeGround.text.trim(),
          yearFounded: _yearFounded.text.trim(),
          logoBytes: _logoBytes,
          logoColor: _logoColor,
          kits: _kits,
          officials: _officials,
          logoUrl: _existingLogoUrl,
          competitions: _competitions,
          clubStatus: _clubStatus,
          lastLeague: _lastLeague.text.trim(),
          letterName: _letter?.name ??
              (_existingLetterUrl != null ? 'Uploaded' : null),
          licenceName: _licence?.name ??
              (_existingLicenceUrl != null ? 'Uploaded' : null),
          agreed: _agreed,
          directions: _directions.text.trim(),
          email: _email.text.trim(),
          enabled: enabled,
          onAgreedChanged: (value) => setState(() => _agreed = value),
          onEdit: (step) => setState(() {
            _forward = false;
            _step = step;
            _editingFromReview = true;
          }),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _stepTitles.length - 1;

    return PopScope(
      canPop: _step == 0 && !_busy && !_editingFromReview,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        if (_editingFromReview || _step > 0) _back();
      },
      child: Scaffold(
        appBar: GedfaAppBar(
          title: _existing == null ? 'Register your team' : 'Edit registration',
          // "Step 2 of 4 · Club status"
          subtitle: _step < _countedSteps
              ? 'Step ${_step + 1} of $_countedSteps · ${_stepTitles[_step]}'
              : _stepTitles[_step],
        ),
        body: Column(
          children: [
            _ProgressHeader(step: _step),
            Expanded(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  // Remove the old step immediately, so two steps never overlap
                  layoutBuilder: (current, previous) =>
                      current ?? const SizedBox.shrink(),
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween(
                      begin: Offset(_forward ? 0.08 : -0.08, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStep(),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          backLabel: _step == 0 && !_editingFromReview ? 'Cancel' : 'Back',
          nextLabel: isLast
              ? (_existing == null ? 'Submit registration' : 'Send changes')
              : _editingFromReview
                  ? 'Save & review'
                  : _step + 1 == _countedSteps
                      ? 'Review and submit'
                      : 'Next: ${_stepTitles[_step + 1].toLowerCase()}',
          busy: _busy || _checking,
          onBack: _back,
          onNext: isLast ? (_agreed ? _submit : null) : _next,
        ),
      ),
    );
  }
}

/// Board R1: the step bars, then "Club details › **Club status** › …".
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyBar =
        isDark ? const Color(0xFF13233A) : const Color(0xFFDCE6F2);
    final style = textTheme.bodySmall
        ?.copyWith(fontSize: 12, color: scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ResponsiveCenter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < _countedSteps; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i < _countedSteps - 1 ? 6 : 0,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= step ? scheme.primary : emptyBar,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    for (var i = 0; i < _countedSteps; i++) ...[
                      if (i > 0) const TextSpan(text: ' › '),
                      TextSpan(
                        text: _stepTitles[i],
                        style: i == step
                            ? TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              )
                            : null,
                      ),
                    ],
                  ],
                ),
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.backLabel,
    required this.nextLabel,
    required this.busy,
    required this.onBack,
    required this.onNext,
  });

  final String backLabel;
  final String nextLabel;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback? onNext;

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
              child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onBack,
                    child: Text(backLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: busy ? null : onNext,
                    child: busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.primary,
                            ),
                          )
                        : Text(nextLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}