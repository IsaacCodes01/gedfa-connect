import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/player_profile.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_picks.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_roles.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';

/// Step 2 of a team sheet, Roles & numbers (3.1b, mockup MS4): captain,
/// vice-captain and goalkeeper for this match, the shirt numbers line
/// (opens MS4b), and the team officials.
class RolesStep extends StatelessWidget {
  const RolesStep({
    super.key,
    required this.players,
    required this.picks,
    required this.roles,
    required this.keeperPickedForYou,
    required this.armbands,
    required this.numbers,
    required this.usual,
    required this.officials,
    required this.officialPicks,
    required this.enabled,
    required this.onCaptain,
    required this.onVice,
    required this.onGoalkeeper,
    required this.onNumbers,
    required this.onOfficial,
  });

  /// The pickable players by ID.
  final Map<String, Player> players;
  final SheetPicks picks;

  /// Already fitted to [picks].
  final SheetRoles roles;
  final bool keeperPickedForYou;

  /// The season's captain and vice-captain (Profiles).
  final Armbands armbands;

  /// Every picked player's number for this match.
  final Map<String, int> numbers;

  /// Registered (usual) numbers by player ID.
  final Map<String, int> usual;

  /// The club's officials (Team profile) and which of them are ticked.
  final List<Official> officials;
  final Set<int> officialPicks;
  final bool enabled;
  final ValueChanged<String> onCaptain;
  final ValueChanged<String?> onVice;
  final ValueChanged<String> onGoalkeeper;
  final VoidCallback onNumbers;
  final ValueChanged<int> onOfficial;

  String _who(String id) {
    final p = players[id];
    return p == null ? '' : '#${numbers[id] ?? p.jerseyNo} ${p.fullName}';
  }

  Future<void> _choose(
    BuildContext context, {
    required String title,
    required List<String> from,
    required String? current,
    required ValueChanged<String> onPicked,
    VoidCallback? onNone,
  }) async {
    const none = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onNone != null)
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('No vice-captain'),
                  trailing: current == null ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, none),
                ),
              for (final id in from)
                if (players[id] case final p?)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        '${numbers[id] ?? p.jerseyNo}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(p.fullName),
                    subtitle: Text(
                      picks.starters.contains(id)
                          ? '${p.position.code} · starting'
                          : '${p.position.code} · bench',
                    ),
                    trailing: id == current ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, id),
                  ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    if (picked == none) {
      onNone?.call();
    } else {
      onPicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = [...picks.starters, ...picks.bench];
    final captain = roles.captainId;
    final vice = roles.viceCaptainId;
    final keeper = roles.goalkeeperId;

    final String captainHint;
    if (captain == null) {
      final season = armbands.captainId;
      captainHint = season != null && players[season] != null
          ? "${players[season]!.fullName} (Profiles) isn't starting: "
                'pick one of the 11'
          : 'Pick one of the starting 11';
    } else {
      captainHint = captain == armbands.captainId
          ? 'From Profiles · must start'
          : 'This match only · must start';
    }
    final viceHint = vice == null
        ? 'None · any of the ${picked.length} on the sheet'
        : vice == armbands.viceCaptainId
        ? 'From Profiles · any of the ${picked.length}'
        : 'This match only · any of the ${picked.length}';
    final keeperHint = keeper == null
        ? 'Pick one of the starting 11'
        : keeperPickedForYou
        ? 'The only goalkeeper starting, picked for you'
        : 'Any starter may keep goal';

    // "Clement Baah 17 → 13"
    final changed = [
      for (final id in picked)
        if (players[id] case final p?)
          if (numbers[id] != usual[id])
            '${p.fullName} ${usual[id]} → ${numbers[id]}',
    ];
    final clashes = SheetRoles.clashesIn(numbers);
    final numbersHint = clashes.isNotEmpty
        ? '${clashes.values.first.length == 2 ? 'Two' : clashes.values.first.length} '
              'players wear ${clashes.keys.first}: change one'
        : changed.isEmpty
        ? 'Everyone wears their usual number unless you change it'
        : 'Everyone wears their usual number unless you change it · '
              '${changed.take(2).join(', ')}'
              '${changed.length > 2 ? ' +${changed.length - 2} more' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Head('Armbands and goalkeeper', 'This match only'),
        DashboardCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _RoleRow(
                badge: const _Badge.text('C', AccentTone.gold),
                label: 'Captain',
                value: captain == null ? null : _who(captain),
                hint: captainHint,
                enabled: enabled,
                onChange: () => _choose(
                  context,
                  title: 'Captain for this match',
                  from: picks.starters,
                  current: captain,
                  onPicked: onCaptain,
                ),
              ),
              const Divider(height: 1),
              _RoleRow(
                badge: const _Badge.text('VC', AccentTone.grey),
                label: 'Vice-captain',
                value: vice == null ? 'None' : _who(vice),
                hint: viceHint,
                optional: true,
                enabled: enabled,
                onChange: () => _choose(
                  context,
                  title: 'Vice-captain for this match',
                  from: [
                    for (final id in picked)
                      if (id != captain) id,
                  ],
                  current: vice,
                  onPicked: onVice,
                  onNone: () => onVice(null),
                ),
              ),
              const Divider(height: 1),
              _RoleRow(
                badge: const _Badge.icon(
                  Icons.sports_handball,
                  AccentTone.green,
                ),
                label: 'Goalkeeper',
                value: keeper == null ? null : _who(keeper),
                hint: keeperHint,
                enabled: enabled,
                onChange: () => _choose(
                  context,
                  title: 'Goalkeeper for this match',
                  from: picks.starters,
                  current: keeper,
                  onPicked: onGoalkeeper,
                ),
              ),
            ],
          ),
        ),
        const _Hint(
          "Changing an armband here changes this match only; Profiles keeps "
          "the season's captain and vice-captain.",
        ),
        const _Head('Shirt numbers', 'This match only'),
        DashboardCard(
          padding: EdgeInsets.zero,
          child: _RoleRow(
            badge: const _Badge.icon(Icons.checkroom, AccentTone.blue),
            value: '${picked.length} numbers · ${changed.length} changed',
            hint: numbersHint,
            hintIsProblem: clashes.isNotEmpty,
            action: 'Change',
            actionIcon: Icons.chevron_right,
            enabled: true,
            onChange: onNumbers,
          ),
        ),
        _Head('Team officials', '${officialPicks.length} of $maxOfficials'),
        DashboardCard(
          padding: EdgeInsets.zero,
          child: officials.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No officials in Team profile yet.'),
                )
              : Column(
                  children: [
                    for (final (i, o) in officials.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      _OfficialRow(
                        official: o,
                        ticked: officialPicks.contains(i),
                        enabled: enabled && !o.role.isRequired,
                        onTap: () => onOfficial(i),
                      ),
                    ],
                  ],
                ),
        ),
        const _Hint(
          'Officials come from Team profile (up to 7). To add one, '
          'add them there.',
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.title, this.note);

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: .4,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: style)),
          Text(note, style: style),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// The round icon on a role row: "C", "VC", a glove or a shirt.
class _Badge extends StatelessWidget {
  const _Badge.text(this.text, this.tone) : icon = null;
  const _Badge.icon(this.icon, this.tone) : text = null;

  final String? text;
  final IconData? icon;
  final AccentTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final captain = text == 'C';
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: captain ? const Color(0xFFFCD116) : tone.background(isDark),
      ),
      child: icon != null
          ? Icon(icon, size: 19, color: tone.foreground(isDark))
          : Text(
              text!,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: text!.length > 1 ? 12.5 : 14,
                color: captain
                    ? const Color(0xFF3A2C00)
                    : tone.foreground(isDark),
              ),
            ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.badge,
    this.label,
    required this.value,
    required this.hint,
    required this.enabled,
    required this.onChange,
    this.optional = false,
    this.hintIsProblem = false,
    this.action = 'Change',
    this.actionIcon = Icons.expand_more,
  });

  final Widget badge;
  final String? label;

  /// null = not picked yet (shown in red).
  final String? value;
  final String hint;
  final bool optional;
  final bool hintIsProblem;
  final bool enabled;
  final VoidCallback onChange;
  final String action;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final missing = value == null && !optional;
    final red = AccentTone.red.foreground(isDark);
    return InkWell(
      onTap: enabled ? onChange : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label case final l?)
                    Text(
                      l,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    value ?? 'Not picked',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: missing ? red : null,
                    ),
                  ),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: hintIsProblem || missing
                          ? red
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: 6),
              Text(
                action,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              Icon(actionIcon, size: 18, color: scheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

/// ☑ Kofi Mensah · CAF D / Head coach · required
class _OfficialRow extends StatelessWidget {
  const _OfficialRow({
    required this.official,
    required this.ticked,
    required this.enabled,
    required this.onTap,
  });

  final Official official;
  final bool ticked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = official;
    final licence = o.licence?.trim();
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            Checkbox(value: ticked, onChanged: enabled ? (_) => onTap() : null),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${o.name}'
                    '${licence == null || licence.isEmpty ? '' : ' · $licence'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    o.role.isRequired ? '${o.roleText} · required' : o.roleText,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (o.role.isRequired)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
