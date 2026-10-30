import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/passport_photo.dart';
import 'package:gedfa_connect/core/utils/phone.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';


/// Youngest allowed age for the Division side.
const _minDivisionAge = 13;

class PlayerFormScreen extends ConsumerStatefulWidget {
  /// [playerId] null = Add player, otherwise Edit player.
  /// [juvenileGroup] ('U13', 'U15' or 'U17') adds a juvenile player (2.14).
  const PlayerFormScreen({super.key, this.playerId, this.juvenileGroup});

  final String? playerId;
  final String? juvenileGroup;

  @override
  ConsumerState<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends ConsumerState<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dobText = TextEditingController();
  final _jersey = TextEditingController();

  DateTime? _dob;
  Position? _position;
  ProcessedPhoto? _newPhoto; // picked in this visit, not uploaded yet
  Player? _existing; // the player being edited
  bool _prefilled = false;
  bool _showErrors = false;
  bool _busy = false;

  // Juvenile only (2.14)
  late AgeGroup? _ageGroup = AgeGroup.fromString(widget.juvenileGroup);
  GuardianRelation? _relation;
  final _guardianName = TextEditingController();
  final _guardianPhone = TextEditingController();

  bool get _isEdit => widget.playerId != null;

  /// Division, or Juvenile when adding to an age group / editing one.
  Competition get _category =>
      _existing?.category ??
      (widget.juvenileGroup != null
          ? Competition.juvenile
          : Competition.division);

  bool get _isJuvenile => _category == Competition.juvenile;

  /// True if there is a photo: a new one, or one already saved.
  bool get _hasPhoto =>
      _newPhoto != null || (_existing?.photoUrl?.isNotEmpty ?? false);

  @override
  void dispose() {
    _name.dispose();
    _dobText.dispose();
    _jersey.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    super.dispose();
  }

  /// Copies the saved player into the form, once.
  void _prefill(Player player) {
    _existing = player;
    _name.text = player.fullName;
    _dob = player.dob;
    _dobText.text = formatDate(player.dob);
    _position = player.position;
    _jersey.text = '${player.jerseyNo}';
    _ageGroup = player.ageGroup;
    final guardian = player.guardian;
    if (guardian != null) {
      _relation = guardian.relation;
      _guardianName.text = guardian.name;
      _guardianPhone.text = guardian.phone;
    }
    _prefilled = true;
  }

  // ---------- Date of birth ----------

  Future<void> _pickDob() async {
    final now = DateTime.now();
    // Juvenile: any child from 5 up (the age box below says if they're
    // too old). Division: 13 and older.
    final latest = _isJuvenile
        ? DateTime(now.year - 5, now.month, now.day)
        : DateTime(now.year - _minDivisionAge, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _dob ?? DateTime(now.year - (_isJuvenile ? 12 : 20), 1, 1),
      firstDate: DateTime(1960),
      lastDate: latest,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Date of birth',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dob = DateTime(picked.year, picked.month, picked.day);
      _dobText.text = formatDate(_dob!);
      // Keep the chosen group only if the child may play in it
      final allowed = AgeGroup.allowedFor(_dob!);
      if (_isJuvenile && !allowed.contains(_ageGroup)) {
        _ageGroup = allowed.isEmpty ? _ageGroup : allowed.first;
      }
    });
  }

  // ---------- Jersey number ----------

  /// The player (other than this one) already wearing [number], if any.
  Player? _holderOf(int number, List<Player> squad) {
    for (final player in squad) {
      if (player.jerseyNo == number && player.id != _existing?.id) {
        return player;
      }
    }
    return null;
  }

  String? _jerseyError(String? value, List<Player> squad) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 1 || number > 99) {
      return 'Enter a number from 1 to 99';
    }
    final holder = _holderOf(number, squad);
    if (holder != null) return '#$number is taken by ${holder.fullName}';
    return null;
  }

  // ---------- Save ----------

  /// "name", "name and photo", "name, jersey number and photo"
  static String _joinChanges(List<String> changes) {
    if (changes.length == 1) return changes.first;
    final allButLast = changes.sublist(0, changes.length - 1).join(', ');
    return '$allButLast and ${changes.last}';
  }

  Future<bool> _confirmReapproval(List<String> changes) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send back to the FA?'),
        content: Text(
          'You changed the ${_joinChanges(changes)}. '
          'The player will be Pending until the FA approves them again. '
          'Their player ID stays the same.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save and send'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save(Team team, List<Player> squad) async {
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    final formOk = _formKey.currentState!.validate();
    final juvenileOk = !_isJuvenile ||
        (_dob != null &&
            AgeGroup.allowedFor(_dob!).contains(_ageGroup) &&
            _relation != null);
    if (!formOk || !_hasPhoto || !juvenileOk) {
      AppToast.warning(context, 'Please fix the highlighted fields.');
      return;
    }

    final existing = _existing;
    final draft = Player(
      id: existing?.id ?? '',
      teamId: team.id,
      teamName: team.name,
      category: _category,
      ageGroup: _isJuvenile ? _ageGroup : null,
      guardian: _isJuvenile
          ? Guardian(
              relation: _relation!,
              name: _guardianName.text,
              phone: normalizeGhanaPhone(_guardianPhone.text) ??
                  _guardianPhone.text.trim(),
            )
          : null,
      fullName: _name.text.trim(),
      dob: _dob!,
      position: _position!,
      jerseyNo: int.parse(_jersey.text.trim()),
      status: existing?.status ?? ApprovalStatus.pending,
      playerCode: existing?.playerCode,
      photoUrl: existing?.photoUrl,
      thumbUrl: existing?.thumbUrl,
    );

    // The FA's league settings (2.13d): the window and the squad size
    final league = ref.read(leagueSettingsProvider).value ??
        const LeagueSettings();
    if (existing == null && !league.playerRegistrationOpen) {
      AppToast.warning(
        context,
        'Player registration is closed. The FA will open it again.',
      );
      return;
    }
    // Juvenile: the limit is per age group
    final sameSquad = _isJuvenile
        ? squad.where((p) => p.ageGroup == _ageGroup).length
        : squad.length;
    if (existing == null && sameSquad >= league.maxSquadSize) {
      AppToast.warning(
        context,
        'Your squad is full (${league.maxSquadSize} players).',
      );
      return;
    }
    final newPhoto = _newPhoto;
    if (existing != null && existing.isApproved) {
      final changes = reapprovalChanges(
        existing,
        draft,
        photoChanged: newPhoto != null,
      );
      if (changes.isNotEmpty) {
        if (!await _confirmReapproval(changes) || !mounted) return;
      }
    }

    setState(() => _busy = true);
    try {
      final repository = ref.read(playerRepositoryProvider);
      if (existing == null) {
        // _hasPhoto was checked above, so a new player always has one
        await repository.create(draft, photo: newPhoto!);
        if (!mounted) return;
        AppToast.success(
          context,
          draft.isJuvenile
              ? '${draft.fullName} added. Bring them to the screening day.'
              : '${draft.fullName} sent to the FA.',
        );
        context.go(Routes.team);
      } else {
        await repository.update(existing, draft, newPhoto: newPhoto);
        if (!mounted) return;
        AppToast.success(context, 'Changes saved.');
        context.go(Routes.player(existing.id));
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancel() {
    final existing = _existing;
    context.go(existing == null ? Routes.team : Routes.player(existing.id));
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(myTeamProvider).value;
    final playersAsync = ref.watch(teamPlayersProvider);
    final title = _isEdit
        ? 'Edit player'
        : _isJuvenile
            ? 'Add ${_ageGroup?.label ?? 'juvenile'} player'
            : 'Add player';

    if (team == null || !playersAsync.hasValue) {
      return Scaffold(
        appBar: GedfaAppBar(title: title),
        body: const LoadingView(),
      );
    }

    final allPlayers = playersAsync.value!;
    if (_isEdit && !_prefilled) {
      final found = allPlayers.where((p) => p.id == widget.playerId);
      if (found.isEmpty) {
        return Scaffold(
          appBar: GedfaAppBar(title: title),
          body: const EmptyView(
            icon: Icons.person_off_outlined,
            title: 'Player not found',
            message: 'This player may have been removed.',
          ),
        );
      }
      _prefill(found.first);
    }

    final category = _category;
    final squad = allPlayers.where((p) => p.category == category).toList();
    // Jersey numbers: Division, or one juvenile age group
    final numbersSquad = _isJuvenile
        ? squad.where((p) => p.ageGroup == _ageGroup).toList()
        : squad;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: GedfaAppBar(title: title),
        bottomNavigationBar: _BottomBar(
          busy: _busy,
          saveLabel: _isEdit
              ? 'Save changes'
              : _isJuvenile
                  ? 'Add for screening'
                  : 'Send for FA approval',
          onCancel: _cancel,
          onSave: () => _save(team, squad),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _showErrors
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _fields(numbersSquad, category),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(List<Player> squad, Competition category) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 16);

    final number = int.tryParse(_jersey.text.trim());
    final numberIsFree = number != null &&
        number >= 1 &&
        number <= 99 &&
        _holderOf(number, squad) == null;
    final used = [
      for (final p in squad)
        if (p.id != _existing?.id) p.jerseyNo,
    ]..sort();

    return [
      // Which side the player joins
      Row(
        children: [
          Text('Adding to',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Chip(
            avatar: Icon(Icons.shield_outlined,
                size: 16, color: scheme.primary),
            label: Text(
              _isJuvenile && _ageGroup != null
                  ? 'Juvenile ${_ageGroup!.label}'
                  : '${category.label} squad',
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      const SizedBox(height: 8),

      // Passport photo (required)
      PassportPhotoPicker(
        name: _name.text,
        bytes: _newPhoto?.full,
        url: _existing?.photoUrl,
        enabled: !_busy,
        errorText:
            _showErrors && !_hasPhoto ? 'Add a passport photo' : null,
        onPicked: (photo) => setState(() => _newPhoto = photo),
      ),
      gap,

      // Full name
      TextFormField(
        controller: _name,
        enabled: !_busy,
        decoration: const InputDecoration(
          labelText: 'Full name',
          helperText: 'As it should appear on team sheets',
        ),
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        inputFormatters: [LengthLimitingTextInputFormatter(80)],
        validator: (value) {
          final name = value?.trim() ?? '';
          if (name.isEmpty) return "Enter the player's full name";
          if (!name.contains(' ')) return 'Enter first name and surname';
          if (name.length < 3) return 'The name is too short';
          return null;
        },
      ),
      gap,

      // Date of birth (picker only)
      TextFormField(
        controller: _dobText,
        enabled: !_busy,
        readOnly: true,
        onTap: _pickDob,
        decoration: InputDecoration(
          labelText: 'Date of birth',
          hintText: 'Pick a date',
          helperText: _dob == null
              ? 'Never shown publicly'
              : 'Age ${_ageOf(_dob!)} · never shown publicly',
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        validator: (_) => _dob == null ? 'Pick the date of birth' : null,
      ),
      gap,
      if (_isJuvenile) ...[
        _AgeBox(dob: _dob),
        if (_dob != null && AgeGroup.ownGroup(_dob!) != null) ...[
          const SizedBox(height: 12),
          _GroupChips(
            dob: _dob!,
            selected: _ageGroup,
            enabled: !_busy,
            onSelected: (group) => setState(() => _ageGroup = group),
          ),
        ],
        gap,
      ],

      // Position (23 positions in 4 groups)
      FormField<Position>(
        initialValue: _position,
        enabled: !_busy,
        validator: (value) => value == null ? 'Choose a position' : null,
        builder: (field) => _PositionPicker(
          selected: field.value,
          enabled: !_busy,
          errorText: field.errorText,
          onSelected: (position) {
            field.didChange(position);
            setState(() => _position = position);
          },
        ),
      ),
      gap,

      // Jersey number with a live check
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: _jersey,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Jersey number'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              onChanged: (_) => setState(() {}),
              validator: (value) => _jerseyError(value, squad),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: numberIsFree
                  ? Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text('#$number is free',
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        used.isEmpty
            ? '1 to 99. No numbers used yet.'
            : '1 to 99. Already used: ${used.join(', ')}',
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      gap,

      if (_isJuvenile) ...[
        _GuardianFields(
          relation: _relation,
          name: _guardianName,
          phone: _guardianPhone,
          enabled: !_busy,
          showErrors: _showErrors,
          onRelation: (r) => setState(() => _relation = r),
        ),
        gap,
      ],

      // Info box
      Container(
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
              child: Text(
                _isJuvenile
                    ? 'New juvenile players wait for the screening day. The '
                        'FA checks each child in person and passes them in '
                        'the group they really fit (moving them up if '
                        'needed), or marks them not eligible.'
                    : 'The FA checks every player. After approval, changing '
                        'the name, date of birth, jersey number or photo '
                        'needs FA approval again.',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  static int _ageOf(DateTime dob) {
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }
}

/// Board J2: "Age group: U13 · born 2015: 11 in 2026", or red
/// "Too old for Juvenile".
class _AgeBox extends StatelessWidget {
  const _AgeBox({required this.dob});

  final DateTime? dob;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dob = this.dob;
    if (dob == null) return const SizedBox.shrink();

    final own = AgeGroup.ownGroup(dob);
    final age = AgeGroup.seasonAge(dob);
    final year = Season.startYear(Season.current);
    final season = Season.label(Season.current);
    final (bg, ink) = own == null
        ? (
            isDark ? const Color(0xFF4A1820) : const Color(0xFFFDE7EA),
            scheme.error,
          )
        : (
            isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA),
            isDark ? const Color(0xFFCFE4FB) : const Color(0xFF0B3F7A),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            own == null ? 'Too old for Juvenile' : 'Age group: ${own.label}',
            style: textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: ink),
          ),
          const SizedBox(height: 4),
          Text(
            own == null
                ? 'Born ${dob.year}: $age in $year. Juvenile ends at 17; '
                    'register this player in the Division instead.'
                : 'Born ${dob.year}: $age in $year, the year the $season '
                    'season starts.',
            style: textTheme.bodySmall
                ?.copyWith(fontSize: 12.5, height: 1.45, color: ink),
          ),
        ],
      ),
    );
  }
}

/// "Register in  [U13] [U15] [U17]": own group or older (playing up).
class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.dob,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final DateTime dob;
  final AgeGroup? selected;
  final bool enabled;
  final ValueChanged<AgeGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final own = AgeGroup.ownGroup(dob);
    final allowed = AgeGroup.allowedFor(dob);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Register in',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final group in AgeGroup.values) ...[
              if (group != AgeGroup.values.first) const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text(group.label),
                  selected: selected == group,
                  showCheckmark: false,
                  // Younger groups are greyed out: nobody plays down
                  onSelected: enabled && allowed.contains(group)
                      ? (_) => onSelected(group)
                      : null,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          selected == own
              ? 'Own age group. Younger players can play up; nobody can '
                  'play down.'
              : 'Playing up in ${selected?.label}. On team sheets the GFA '
                  'limits how many younger players play up.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Parent or guardian (required for juvenile players).
class _GuardianFields extends StatelessWidget {
  const _GuardianFields({
    required this.relation,
    required this.name,
    required this.phone,
    required this.enabled,
    required this.showErrors,
    required this.onRelation,
  });

  final GuardianRelation? relation;
  final TextEditingController name;
  final TextEditingController phone;
  final bool enabled;
  final bool showErrors;
  final ValueChanged<GuardianRelation> onRelation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Parent or guardian *',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in GuardianRelation.values)
              ChoiceChip(
                label: Text(r.label),
                selected: relation == r,
                showCheckmark: false,
                onSelected: enabled ? (_) => onRelation(r) : null,
              ),
          ],
        ),
        if (showErrors && relation == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Choose who they are',
              style: textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        const SizedBox(height: 12),
        TextFormField(
          controller: name,
          enabled: enabled,
          decoration: const InputDecoration(labelText: 'Their full name *'),
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          validator: (v) => (v?.trim().length ?? 0) < 3
              ? "Enter the parent or guardian's name"
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phone,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Their phone *',
            hintText: 'e.g. 024 555 1234',
            helperText: 'Only the team and the FA see this.',
          ),
          keyboardType: TextInputType.phone,
          validator: Validators.ghanaPhone,
        ),
      ],
    );
  }
}

class _PositionPicker extends StatelessWidget {
  const _PositionPicker({
    required this.selected,
    required this.enabled,
    required this.errorText,
    required this.onSelected,
  });

  final Position? selected;
  final bool enabled;
  final String? errorText;
  final ValueChanged<Position> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final selected = this.selected;
    final error = errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Position',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (selected != null)
              Text(
                selected.display,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final group in PositionGroup.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      group.code,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final position in Position.inGroup(group))
                        ChoiceChip(
                          label: Text(position.code),
                          tooltip: position.label,
                          selected: selected == position,
                          showCheckmark: false,
                          onSelected: enabled
                              ? (_) => onSelected(position)
                              : null,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (error != null)
          Text(
            error,
            style: textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.busy,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
  });

  final bool busy;
  final String saveLabel;
  final VoidCallback onCancel;
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: busy ? null : onSave,
                      child: busy
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: scheme.primary,
                              ),
                            )
                          : Text(saveLabel),
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
