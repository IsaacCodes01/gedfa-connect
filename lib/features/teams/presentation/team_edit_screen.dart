import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_profile_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_photos.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';
import 'package:gedfa_connect/features/teams/presentation/kit_editor_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/kit_photos_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/colours_step.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/kits_step.dart';
import 'package:gedfa_connect/features/teams/presentation/steps/officials_step.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/officials_editor.dart';
import 'package:go_router/go_router.dart';

/// Team profile › Edit one section (2.10a, board P3). It reuses the
/// registration steps (colours, kits, officials), so they look and work
/// the same. Saving writes only that section, straight away, and the FA
/// gets a note in the bell.
class TeamEditScreen extends ConsumerWidget {
  const TeamEditScreen({super.key, required this.section});

  final TeamSection section;

  static String titleFor(TeamSection section) => switch (section) {
        TeamSection.details => 'Town and home ground',
        TeamSection.colours => 'Team colours',
        TeamSection.kits => 'Kits',
        TeamSection.officials => 'Officials',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(myTeamDetailsProvider);
    final teamId = ref.watch(appUserProvider).value?.teamId;
    final team = detailsAsync.value;

    // Data first; the editor copies it once and then keeps its own
    if (team == null || teamId == null) {
      return Scaffold(
        appBar: GedfaAppBar(
          title: titleFor(section),
          leading: BackButton(onPressed: () => context.go(Routes.teamClub)),
        ),
        body: detailsAsync.hasError
            ? ErrorView(message: appErrorMessage(detailsAsync.error!))
            : const LoadingView(),
      );
    }
    return _Editor(section: section, team: team, teamId: teamId);
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({
    required this.section,
    required this.team,
    required this.teamId,
  });

  final TeamSection section;
  final TeamDetails team;
  final String teamId;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _formKey = GlobalKey<FormState>();
  late final _town = TextEditingController(text: widget.team.town);
  late final _ground = TextEditingController(text: widget.team.homeGround);
  late final _directions =
      TextEditingController(text: widget.team.homeGroundDirections ?? '');

  late TeamColours _colours = widget.team.colours ??
      TeamColours.suggested(
        homeKit: widget.team.homeKit,
        awayKit: widget.team.awayKit,
      );

  /// The first set is `kits` (Division, or Juvenile for a Juvenile-only
  /// club); the second, `juvenileKits`, only for a club in both.
  late final KitSet _kits = {
    for (final slot in KitSlot.values) slot: widget.team.divisionKits[slot],
  };
  late final KitSet _juvenileKits = {
    for (final slot in KitSlot.values) slot: widget.team.juvenileKits[slot],
  };

  late final List<OfficialDraft> _officials =
      widget.team.officials.map(OfficialDraft.fromOfficial).toList();

  bool _showErrors = false;
  bool _busy = false;

  Set<Competition> get _competitions => widget.team.categories;
  bool get _both => _competitions.length > 1;

  @override
  void dispose() {
    _town.dispose();
    _ground.dispose();
    _directions.dispose();
    for (final draft in _officials) {
      draft.dispose();
    }
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.teamClub);
    }
  }

  // ---------- Kits (same as registration) ----------

  Map<Competition, KitSet> get _kitSets => _both
      ? {Competition.division: _kits, Competition.juvenile: _juvenileKits}
      : {_competitions.first: _kits};

  KitSet _setFor(Competition competition) =>
      _both && competition == Competition.juvenile ? _juvenileKits : _kits;

  String _kitTitle(Competition competition, KitSlot slot) =>
      _both && competition == Competition.juvenile
          ? 'Juvenile ${slot.label.toLowerCase()}'
          : slot.label;

  Future<void> _uploadKit(Competition competition, KitSlot slot) async {
    final kits = _setFor(competition);
    final result = await KitPhotosScreen.open(
      context,
      title: _kitTitle(competition, slot),
      initial: kits[slot]?.photos,
    );
    if (result != null && mounted) {
      setState(() => kits[slot] = Kit.fromPhotos(result));
    }
  }

  Future<void> _designKit(Competition competition, KitSlot slot) async {
    final kits = _setFor(competition);
    final current = kits[slot];
    final result = await KitEditorScreen.open(
      context,
      title: _kitTitle(competition, slot),
      initial: current == null || current.isPhotos ? null : current,
    );
    if (result != null && mounted) setState(() => kits[slot] = result);
  }

  void _removeKit(Competition competition, KitSlot slot) =>
      setState(() => _setFor(competition)[slot] = null);

  /// New kit photos go up first; the kits then keep their links.
  Future<Map<String, dynamic>> _kitMap(KitSet kits, String set) async {
    final repository = ref.read(teamRequestRepositoryProvider);
    final uid = ref.read(authStateProvider).value?.uid ?? '';
    final result = <String, dynamic>{};
    for (final MapEntry(key: slot, value: kit) in kits.entries) {
      if (kit == null) continue;
      var saved = kit;
      final photos = kit.photos;
      if (photos != null && photos.hasNewPhotos) {
        var uploaded = photos;
        for (final part in KitPart.values) {
          final bytes = photos[part].bytes;
          if (bytes == null) continue;
          final url = await repository.uploadKitPhoto(
            uid: uid,
            set: set,
            slot: slot.name,
            part: part.name,
            bytes: bytes,
          );
          uploaded = uploaded.withPart(part, KitPhoto(url: url));
        }
        saved = Kit.fromPhotos(uploaded);
      }
      result[slot.name] = saved.toMap();
    }
    return result;
  }

  // ---------- Save ----------

  String? get _problem => switch (widget.section) {
        TeamSection.details =>
          _formKey.currentState?.validate() ?? false
              ? null
              : 'Check the fields in red.',
        TeamSection.colours => null,
        TeamSection.kits => kitSetComplete(_kits) &&
                (!_both || kitSetComplete(_juvenileKits))
            ? null
            : 'Home, away and goalkeeper kits are needed.',
        TeamSection.officials => _officials.length < 2
            ? 'Keep at least 2 officials.'
            : _officials.every((d) => d.isComplete)
                ? null
                : 'Complete every official (name and phone).',
      };

  Future<Map<String, dynamic>> _changes() async {
    switch (widget.section) {
      case TeamSection.details:
        final directions = _directions.text.trim();
        return {
          'town': _town.text.trim(),
          'homeGround': _ground.text.trim(),
          'homeGroundDirections': directions.isEmpty ? null : directions,
        };
      case TeamSection.colours:
        return {'colours': _colours.toMap()};
      case TeamSection.kits:
        final firstSet = _both || _competitions.contains(Competition.division)
            ? 'division'
            : 'juvenile';
        return {
          'kits': await _kitMap(_kits, firstSet),
          if (_both) 'juvenileKits': await _kitMap(_juvenileKits, 'juvenile'),
        };
      case TeamSection.officials:
        return {
          'officials': [
            for (final draft in _officials) draft.toOfficial().toMap(),
          ],
        };
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    final problem = _problem;
    if (problem != null) {
      AppToast.warning(context, problem);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(teamProfileRepositoryProvider).saveDirect(
            teamId: widget.teamId,
            teamName: widget.team.teamName,
            section: widget.section,
            changes: await _changes(),
          );
      if (!mounted) return;
      AppToast.success(context, 'Saved. The FA has been told.');
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
    final enabled = !_busy;
    final Widget body = switch (widget.section) {
      TeamSection.details => _detailsForm(enabled),
      TeamSection.colours => ColoursStep(
          colours: _colours,
          initials: initialsFor(widget.team.teamName),
          enabled: enabled,
          onChanged: (value) => setState(() => _colours = value),
        ),
      TeamSection.kits => KitsStep(
          competitions: _competitions,
          kits: _kitSets,
          showErrors: _showErrors,
          enabled: enabled,
          onUpload: _uploadKit,
          onDesign: _designKit,
          onRemove: _removeKit,
        ),
      TeamSection.officials => OfficialsStep(
          showErrors: _showErrors,
          enabled: enabled,
          drafts: _officials,
          onAdd: (draft) => setState(() {
            _officials
              ..add(draft)
              ..sort((a, b) => a.role.index.compareTo(b.role.index));
          }),
          onRemove: (draft) {
            setState(() => _officials.remove(draft));
            draft.dispose();
          },
          onChanged: () => setState(() {}),
        ),
    };

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: GedfaAppBar(
          title: TeamEditScreen.titleFor(widget.section),
          subtitle: widget.team.teamName,
          leading: BackButton(onPressed: _busy ? null : _back),
        ),
        bottomNavigationBar: _SaveBar(busy: _busy, onSave: _save),
        body: body,
      ),
    );
  }

  Widget _detailsForm(bool enabled) {
    const gap = SizedBox(height: 14);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _town,
                  enabled: enabled,
                  decoration:
                      const InputDecoration(labelText: 'Town / community'),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(60)],
                  validator: (value) =>
                      Validators.requiredField(value, 'the town'),
                ),
                gap,
                TextFormField(
                  controller: _ground,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Home ground',
                    hintText: 'e.g. Fetteh Park',
                  ),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  validator: (value) =>
                      Validators.requiredField(value, 'the home ground'),
                ),
                gap,
                TextFormField(
                  controller: _directions,
                  enabled: enabled,
                  minLines: 2,
                  maxLines: 3,
                  inputFormatters: [LengthLimitingTextInputFormatter(300)],
                  decoration: const InputDecoration(
                    labelText: 'Directions to the ground (optional)',
                    hintText: 'e.g. Behind the Methodist school',
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                gap,
                Text(
                  'Saves straight away. The FA gets a note in the bell: '
                  '"${widget.team.teamName} updated their home ground".',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
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
                    : const Text('Save'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
