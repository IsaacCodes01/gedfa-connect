import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/connectivity/connectivity_provider.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/short_name.dart';
import 'package:gedfa_connect/core/utils/team_name_key.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:gedfa_connect/features/teams/presentation/kit_editor_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/club_step.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/kits_step.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/officials_step.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/review_step.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/officials_editor.dart';


const _stepTitles = ['Club details', 'Kits', 'Officials', 'Review & submit'];

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
  final _officialsFormKey = GlobalKey<FormState>();

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

  // Step 2: kits
  final Map<KitSlot, Kit?> _kits = {
    for (final slot in KitSlot.values) slot: null,
  };

  // Step 3: officials
  late final List<OfficialDraft> _officials;

  // Step 4: declaration
  bool _agreed = false;

    // Editing an existing request
  TeamRequest? _existing;
  String? _existingLogoUrl;

  @override
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

  // ---------- Step 2 helpers ----------

  Future<void> _editKit(KitSlot slot) async {
    final result = await KitEditorScreen.open(
      context,
      title: slot.label,
      initial: _kits[slot],
    );
    if (result != null && mounted) setState(() => _kits[slot] = result);
  }

  // ---------- Step 3 helpers ----------

  void _addOfficial(OfficialRole role) {
    setState(() {
      _officials
        ..add(OfficialDraft(role))
        ..sort((a, b) => a.role.index.compareTo(b.role.index));
    });
  }

  void _removeOfficial(OfficialDraft draft) {
    setState(() => _officials.remove(draft));
    draft.dispose();
  }

  // ---------- Navigation ----------

  Future<bool> _validateCurrentStep() async {
    switch (_step) {
      case 0:
        if (!_clubFormKey.currentState!.validate()) return false;
        return _isNameAvailable();
      case 1:
        return KitSlot.values
            .where((slot) => slot.isRequired)
            .every((slot) => _kits[slot] != null);
      case 2:
        return _officialsFormKey.currentState!.validate();
      default:
        return true;
    }
  }

    Future<void> _next() async {
    FocusScope.of(context).unfocus();

    // Only step 1 waits for the internet (team name check).
    // The other steps check instantly, so nothing turns grey.
    if (_step == 0) setState(() => _checking = true);
    final ok = await _validateCurrentStep();
    if (!mounted) return;
    if (_step == 0) setState(() => _checking = false);

    if (!ok) {
      setState(() => _showErrors.add(_step));
      AppToast.warning(
        context,
        _step == 1
            ? 'Set the home, away and goalkeeper kits to continue.'
            : 'Please fix the highlighted fields.',
      );
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
    } else if (_step == 0) {
      context.go(Routes.welcome);
    } else {
      setState(() {
        _forward = false;
        _step--;
      });
    }
  }

  // ---------- Submit ----------

  TeamRequest _buildRequest(String uid, String? logoUrl) {
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

      final request = _buildRequest(uid, logoUrl);
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
        _showErrors.add(0);
        _step = 0;
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
      0 => ClubStep(
          formKey: _clubFormKey,
          showErrors: _showErrors.contains(0),
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
        ),
      1 => KitsStep(
          kits: _kits,
          showErrors: _showErrors.contains(1),
          enabled: enabled,
          onEdit: _editKit,
          onRemove: (slot) => setState(() => _kits[slot] = null),
        ),
      2 => OfficialsStep(
          formKey: _officialsFormKey,
          showErrors: _showErrors.contains(2),
          enabled: enabled,
          drafts: _officials,
          onAdd: _addOfficial,
          onRemove: _removeOfficial,
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
              : 'Next: ${_stepTitles[_step + 1].split(' ').first}',
          busy: _busy || _checking,
          onBack: _back,
          onNext: isLast ? (_agreed ? _submit : null) : _next,
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: ResponsiveCenter(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _stepTitles[step],
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Text(
                  'Step ${step + 1} of ${_stepTitles.length}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < _stepTitles.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i < _stepTitles.length - 1 ? 6 : 0,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= step
                              ? scheme.primary
                              : scheme.outline.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
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