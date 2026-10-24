import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/players/data/player_profile_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/player_profile.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:go_router/go_router.dart';

/// Team admin: edit a player's profile. Everything is optional and saves
/// straight away: no FA approval, and the registration is not touched.
///
/// Waits for the player, their profile and the armbands, then shows the
/// form (so the form starts with the saved values).
class PlayerProfileEditScreen extends ConsumerWidget {
  const PlayerProfileEditScreen({super.key, required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider(playerId));
    final profiles = ref.watch(teamProfilesProvider);
    final category = player.value?.category.name ?? 'division';
    final armbands = ref.watch(armbandsProvider(category));

    final error = player.error ?? profiles.error ?? armbands.error;
    Widget body;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!player.hasValue || !profiles.hasValue || !armbands.hasValue) {
      body = const LoadingView();
    } else if (player.value == null) {
      body = const EmptyView(
        icon: Icons.search_off_rounded,
        title: 'Player not found',
        message: 'They may have been removed.',
      );
    } else {
      final p = player.requireValue!;
      return _ProfileForm(
        player: p,
        profile: profiles.requireValue[p.id] ??
            PlayerProfile.empty(p.id, p.teamId),
        armbands: armbands.requireValue,
      );
    }
    return Scaffold(
      appBar: const GedfaAppBar(title: 'Edit profile'),
      body: body,
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({
    required this.player,
    required this.profile,
    required this.armbands,
  });

  final Player player;
  final PlayerProfile profile;
  final Armbands armbands;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _height = TextEditingController(text: _num(widget.profile.heightCm));
  late final _weight = TextEditingController(text: _num(widget.profile.weightKg));
  late final _hometown = TextEditingController(text: widget.profile.hometown);
  late final _since = TextEditingController(text: _num(widget.profile.clubSince));
  late final _previous =
      TextEditingController(text: widget.profile.previousClub);
  late final _emName = TextEditingController(text: widget.profile.emergencyName);
  late final _emPhone =
      TextEditingController(text: widget.profile.emergencyPhone);

  late Availability _availability = widget.profile.availability;
  late UnavailableReason? _reason = widget.profile.unavailableReason;
  late DateTime? _expectedBack = widget.profile.expectedBack;
  late Foot? _foot = widget.profile.foot;
  late final Set<Position> _other = {...widget.profile.otherPositions};
  late final Set<Strength> _strengths = {...widget.profile.strengths};
  late Armband _armband = switch (widget.armbands.badgeFor(widget.player.id)) {
    'C' => Armband.captain,
    'VC' => Armband.viceCaptain,
    _ => Armband.none,
  };
  bool _busy = false;

  static String _num(int? value) => value?.toString() ?? '';

  @override
  void dispose() {
    for (final c in [
      _height,
      _weight,
      _hometown,
      _since,
      _previous,
      _emName,
      _emPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Empty = fine; otherwise a whole number between [min] and [max].
  String? Function(String?) _range(int min, int max, String unit) =>
      (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        final n = int.tryParse(text);
        if (n == null || n < min || n > max) {
          return 'Between $min and $max $unit';
        }
        return null;
      };

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedBack ?? now.add(const Duration(days: 14)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Expected back',
    );
    if (picked != null) setState(() => _expectedBack = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    int? number(TextEditingController c) => int.tryParse(c.text.trim());

    final after = PlayerProfile(
      playerId: widget.player.id,
      teamId: widget.player.teamId,
      heightCm: number(_height),
      weightKg: number(_weight),
      foot: _foot,
      otherPositions: _other.toList(),
      strengths: _strengths.toList(),
      hometown: _hometown.text,
      clubSince: number(_since),
      previousClub: _previous.text,
      availability: _availability,
      unavailableReason: _reason,
      expectedBack: _expectedBack,
      emergencyName: _emName.text,
      emergencyPhone: _emPhone.text,
    );

    setState(() => _busy = true);
    try {
      await ref.read(playerProfileRepositoryProvider).save(
            before: widget.profile,
            after: after,
            category: widget.player.category.name,
            armbands: widget.armbands,
            armband: _armband,
          );
      if (!mounted) return;
      AppToast.success(context, 'Profile saved.');
      context.pop();
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Kofi Mensah is captain now. Saving moves the armband to Yaw."
  String _armbandHint() {
    final players = ref.watch(teamPlayersProvider).value ?? const <Player>[];
    String? nameOf(String? id) =>
        players.where((p) => p.id == id).map((p) => p.fullName).firstOrNull;
    final first = widget.player.fullName.split(' ').first;
    final me = widget.player.id;

    final holderId = switch (_armband) {
      Armband.captain => widget.armbands.captainId,
      Armband.viceCaptain => widget.armbands.viceCaptainId,
      Armband.none => null,
    };
    final holder = nameOf(holderId);
    if (holderId != null && holderId != me && holder != null) {
      final role = _armband == Armband.captain ? 'captain' : 'vice-captain';
      return '$holder is $role now. Saving moves the armband to $first.';
    }
    return 'One captain and one vice-captain per squad. Team sheets fill '
        'them in automatically; you can still change them for one match '
        'there.';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final player = widget.player;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
          child: Text(
            text.toUpperCase(),
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        );

    Widget label(String text, [String? help]) => Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (help != null)
                Text(
                  help,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        );

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Edit profile',
        subtitle: '${player.fullName} · #${player.jerseyNo}',
        leading: CloseButton(onPressed: () => context.pop()),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            // heightFactor: 1 = only as tall as the button
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Save profile'),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InfoBox(
                    icon: Icons.info_outline_rounded,
                    color: scheme.primary,
                    child: const Text(
                      "All optional. Saved straight away: these details don't "
                      "need FA approval and don't change the player's "
                      'registration.',
                    ),
                  ),

                  heading('Availability'),
                  _Segmented<Availability>(
                    values: Availability.values,
                    labelOf: (a) => a.label,
                    selected: _availability,
                    onChanged: (a) => setState(() => _availability = a),
                  ),
                  if (_availability == Availability.unavailable) ...[
                    label('Why?', 'Optional. Only the reason, no details.'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in UnavailableReason.values)
                          ChoiceChip(
                            label: Text(r.label),
                            selected: _reason == r,
                            onSelected: (on) =>
                                setState(() => _reason = on ? r : null),
                          ),
                      ],
                    ),
                  ],
                  if (_availability != Availability.available) ...[
                    label('Expected back (optional)',
                        "Only the date. Don't write medical details here."),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              _expectedBack == null
                                  ? 'Pick a date'
                                  : formatDate(_expectedBack!),
                            ),
                          ),
                        ),
                        if (_expectedBack != null)
                          IconButton(
                            tooltip: 'Clear the date',
                            onPressed: () =>
                                setState(() => _expectedBack = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                  ],

                  heading('Body'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _height,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Height (cm)'),
                          validator: _range(120, 220, 'cm'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _weight,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Weight (kg)'),
                          validator: _range(35, 130, 'kg'),
                        ),
                      ),
                    ],
                  ),
                  label('Preferred foot', 'Tap again to clear.'),
                  _Segmented<Foot?>(
                    values: Foot.values,
                    labelOf: (f) => f!.label,
                    selected: _foot,
                    onChanged: (f) =>
                        setState(() => _foot = _foot == f ? null : f),
                  ),

                  heading('Playing'),
                  label(
                    'Can also play',
                    'Up to 2. Main position: ${player.position.code} '
                        "(change it on the player's registration).",
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in Position.values)
                        if (p != player.position)
                          FilterChip(
                            label: Text(p.code),
                            tooltip: p.label,
                            selected: _other.contains(p),
                            onSelected: (on) => setState(() {
                              if (!on) {
                                _other.remove(p);
                              } else if (_other.length < 2) {
                                _other.add(p);
                              }
                            }),
                          ),
                    ],
                  ),
                  label('Strengths', 'Up to 3.'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in Strength.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _strengths.contains(s),
                          onSelected: (on) => setState(() {
                            if (!on) {
                              _strengths.remove(s);
                            } else if (_strengths.length < 3) {
                              _strengths.add(s);
                            }
                          }),
                        ),
                    ],
                  ),
                  label('Armband'),
                  _Segmented<Armband>(
                    values: Armband.values,
                    labelOf: (a) => switch (a) {
                      Armband.none => 'None',
                      Armband.captain => 'Captain',
                      Armband.viceCaptain => 'Vice-captain',
                    },
                    selected: _armband,
                    onChanged: (a) => setState(() => _armband = a),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _armbandHint(),
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),

                  heading('Background'),
                  TextFormField(
                    controller: _hometown,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(60)],
                    decoration: const InputDecoration(labelText: 'Hometown'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _since,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'At the club since (year)',
                    ),
                    validator: _range(1980, DateTime.now().year, ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _previous,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                    decoration:
                        const InputDecoration(labelText: 'Previous club'),
                  ),

                  heading('Private · team and FA only'),
                  TextFormField(
                    controller: _emName,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                    decoration: const InputDecoration(
                      labelText: 'Emergency contact',
                      hintText: 'e.g. Akua Boateng (mother)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emPhone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [LengthLimitingTextInputFormatter(20)],
                    decoration:
                        const InputDecoration(labelText: 'Their phone'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A grey track with equal options; the selected one is a white
/// (dark mode: blue-grey) rounded square. Like CountTabs, without counts.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFDCE6F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                inMutuallyExclusiveGroup: true,
                checked: values[i] == selected,
                button: true,
                child: Material(
                  color: values[i] == selected
                      ? (isDark ? const Color(0xFF24476E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () => onChanged(values[i]),
                    borderRadius: BorderRadius.circular(11),
                    child: SizedBox(
                      height: 42,
                      child: Center(
                        child: Text(
                          labelOf(values[i]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: values[i] == selected
                                ? (isDark
                                    ? AppColors.darkInk
                                    : const Color(0xFF0B3F7A))
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
