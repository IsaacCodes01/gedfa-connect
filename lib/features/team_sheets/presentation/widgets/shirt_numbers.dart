import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_roles.dart';
import 'package:gedfa_connect/core/widgets/one_line.dart';

/// Shirt numbers for this match (3.1b, mockup MS4b): every picked player
/// with the number they wear today. A changed number shows "usual 17" and
/// Reset; two players with the same number are red until one changes.
/// Tapping a player opens the picker (MS4c).
class ShirtNumbersView extends StatelessWidget {
  const ShirtNumbersView({
    super.key,
    required this.starters,
    required this.bench,
    required this.numbers,
    required this.enabled,
    required this.onNumber,
  });

  final List<Player> starters;
  final List<Player> bench;

  /// Every picked player's number for this match.
  final Map<String, int> numbers;
  final bool enabled;

  /// [player] wears [number] (their usual number = back to normal).
  final void Function(Player player, int number) onNumber;

  Future<void> _pick(BuildContext context, Player p) async {
    final everyone = [...starters, ...bench];
    final number = await showShirtPicker(
      context,
      player: p,
      current: numbers[p.id] ?? p.jerseyNo,
      takenBy: {
        for (final o in everyone)
          if (o.id != p.id && numbers[o.id] != null) numbers[o.id]!: o,
      },
    );
    if (number != null) onNumber(p, number);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clashes = SheetRoles.clashesIn(numbers);
    final everyone = {
      for (final p in [...starters, ...bench]) p.id: p,
    };

    Widget group(String title, List<Player> list, String note) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHead(title, note),
        DashboardCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final p in list)
                _NumberRow(
                  player: p,
                  number: numbers[p.id] ?? p.jerseyNo,
                  sameAs: [
                    for (final id in clashes[numbers[p.id]] ?? const <String>[])
                      if (id != p.id)
                        everyone[id]?.fullName.split(' ').first ?? '',
                  ],
                  enabled: enabled,
                  onTap: () => _pick(context, p),
                  onReset: () => onNumber(p, p.jerseyNo),
                ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (clashes.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccentTone.red.background(isDark),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: AccentTone.red.foreground(isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${clashes.values.first.length == 2 ? 'Two' : clashes.values.first.length} '
                              'players wear ${clashes.keys.first}.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text: ' Give one of them another number.',
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AccentTone.red.foreground(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        group('Starting 11', starters, 'usual numbers'),
        if (bench.isNotEmpty) group('Bench', bench, ''),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: Text(
            "Only this match. The players' usual numbers in Squad don't "
            'change.',
            style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupHead extends StatelessWidget {
  const _GroupHead(this.title, this.note);

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

/// [13] Clement Baah / CF · usual 17 · Reset            ✎
class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.player,
    required this.number,
    required this.sameAs,
    required this.enabled,
    required this.onTap,
    required this.onReset,
  });

  final Player player;
  final int number;

  /// First names of the others wearing [number].
  final List<String> sameAs;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = player;
    final changed = number != p.jerseyNo;
    final bad = sameAs.isNotEmpty;
    final tone = bad
        ? AccentTone.red
        : changed
        ? AccentTone.blue
        : AccentTone.grey;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.background(isDark),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: bad || changed
                      ? tone.foreground(isDark)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: bad || changed ? tone.foreground(isDark) : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        p.position.code,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (changed)
                        FixtureTag(
                          'usual ${p.jerseyNo}',
                          tone: AccentTone.grey,
                        ),
                      if (changed && enabled)
                        InkWell(
                          onTap: onReset,
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      if (bad)
                        FixtureTag(
                          'Same as ${sameAs.join(', ')}',
                          tone: AccentTone.red,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (enabled)
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// The number picker (mockup MS4c): 1 to 30 in a grid, numbers already on
/// the sheet greyed with the wearer's initials, the usual number marked,
/// and a box for any other number up to 99. Returns the number to wear, or
/// null when closed.
Future<int?> showShirtPicker(
  BuildContext context, {
  required Player player,
  required int current,
  required Map<int, Player> takenBy,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _ShirtPicker(player: player, current: current, takenBy: takenBy),
  );
}

class _ShirtPicker extends StatefulWidget {
  const _ShirtPicker({
    required this.player,
    required this.current,
    required this.takenBy,
  });

  final Player player;
  final int current;
  final Map<int, Player> takenBy;

  @override
  State<_ShirtPicker> createState() => _ShirtPickerState();
}

class _ShirtPickerState extends State<_ShirtPicker> {
  late int? _chosen = widget.current;
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  static String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.player;
    final usual = p.jerseyNo;
    final chosen = _chosen;
    final taken = chosen == null ? null : widget.takenBy[chosen];
    final String? error = _typed.text.isNotEmpty && chosen == null
        ? 'From 1 to 99'
        : taken != null
        ? 'Already worn by ${taken.fullName}'
        : null;

    Widget cell(int n) {
      final by = widget.takenBy[n];
      final selected = n == chosen;
      final isUsual = n == usual;
      final blue = AccentTone.blue.foreground(isDark);
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: by != null
            ? null
            : () => setState(() {
                _chosen = n;
                _typed.clear();
              }),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? blue
                : by != null
                ? AccentTone.grey.background(isDark)
                : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? blue
                  : isUsual
                  ? AccentTone.gold.foreground(isDark)
                  : scheme.outlineVariant,
            ),
          ),
          child: Opacity(
            opacity: by != null ? .5 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$n',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: selected
                        ? (isDark ? const Color(0xFF0B1626) : Colors.white)
                        : null,
                  ),
                ),
                if (by != null || isUsual)
                  Text(
                    by != null ? _initials(by.fullName) : 'usual',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: selected
                          ? (isDark ? const Color(0xFF0B1626) : Colors.white)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Shirt for ${p.fullName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Usual number $usual · greyed numbers are already on this '
                'sheet',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.15,
                children: [for (var n = 1; n <= 30; n++) cell(n)],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _typed,
                keyboardType: TextInputType.number,
                maxLength: 2,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.dialpad),
                  hintText: 'Another number (1 to 99)',
                  isDense: true,
                  counterText: '',
                  errorText: error,
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  setState(
                    () => _chosen = v.trim().isEmpty
                        ? widget.current
                        : n != null && SheetRoles.isValidNumber(n)
                        ? n
                        : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: widget.takenBy[usual] != null
                          ? null
                          : () => Navigator.pop(context, usual),
                      child: OneLine(Text('Back to $usual')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: chosen == null || taken != null
                          ? null
                          : () => Navigator.pop(context, chosen),
                      child: OneLine(Text(chosen == null ? 'Wear …' : 'Wear $chosen')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
