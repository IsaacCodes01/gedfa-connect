import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/settings/data/data_saver_provider.dart';

/// Players in rows by position, 3 photo cards per row on a phone.
/// Used by the team's Squad and Positions tabs and by the FA's team screen,
/// so a change to the cards shows everywhere.
///
/// How to use:
/// ```dart
/// PositionRows(
///   sections: sectionsByGroup(players),
///   cardLine: CardLine.squad,
///   onTap: (player) => ...,
/// )
/// ```

// ── What each card's small second line says ─────────────────────────────

enum CardLine {
  /// Team Squad tab: "GE26-0007 · RCB", "AMF · awaiting FA",
  /// "LW · needs correcting".
  squad,

  /// FA: "GE26-0007 · RCB" when approved, "AMF · 22 yrs" otherwise
  /// (the FA checks the age against the photo).
  fa,

  /// Positions tab: "RCB · 24 yrs".
  positionAndAge,
}

// ── Sections ─────────────────────────────────────────────────────────────

/// One row: a heading with a coloured bar, then the players' cards.
class PlayerSection {
  const PlayerSection({
    required this.title,
    required this.accent,
    required this.players,
  });

  final String title; // e.g. "Defenders" or "Left-back (LB)"
  final Color accent;
  final List<Player> players;

  /// Average age in full years, e.g. 22.
  int get averageAge => players.isEmpty
      ? 0
      : (players.map((p) => p.age).reduce((a, b) => a + b) / players.length)
          .round();
}

/// Plural name and accent colour of each position group.
(String, Color) groupStyle(PositionGroup group, {required bool isDark}) =>
    switch (group) {
      PositionGroup.gk => (
          'Goalkeepers',
          isDark ? const Color(0xFFF5D25B) : const Color(0xFF8A6A00)
        ),
      PositionGroup.def => (
          'Defenders',
          isDark ? AppColors.darkLink : AppColors.deepBlue
        ),
      PositionGroup.mid => (
          'Midfielders',
          isDark ? AppColors.darkGreen : AppColors.ghanaGreen
        ),
      PositionGroup.fwd => (
          'Forwards',
          isDark ? const Color(0xFFFF8A94) : AppColors.ghanaRed
        ),
    };

/// Sorts players by position group, then jersey number.
List<Player> sortedBySquadOrder(Iterable<Player> players) => [...players]
  ..sort((a, b) {
    final byGroup = a.positionGroup.index.compareTo(b.positionGroup.index);
    return byGroup != 0 ? byGroup : a.jerseyNo.compareTo(b.jerseyNo);
  });

/// One section per position group that has players:
/// Goalkeepers, Defenders, Midfielders, Forwards.
List<PlayerSection> sectionsByGroup(
  Iterable<Player> players, {
  required bool isDark,
}) {
  final sorted = sortedBySquadOrder(players);
  return [
    for (final group in PositionGroup.values)
      if (sorted.any((p) => p.positionGroup == group))
        PlayerSection(
          title: groupStyle(group, isDark: isDark).$1,
          accent: groupStyle(group, isDark: isDark).$2,
          players: [
            for (final p in sorted)
              if (p.positionGroup == group) p,
          ],
        ),
  ];
}

/// One section per detailed position inside [group], in the order of the
/// Position list: "Centre-back (CB)", "Right centre-back (RCB)", ...
List<PlayerSection> sectionsByPosition(
  Iterable<Player> players,
  PositionGroup group, {
  required bool isDark,
}) {
  final accent = groupStyle(group, isDark: isDark).$2;
  final sorted = sortedBySquadOrder(players);
  return [
    for (final position in Position.inGroup(group))
      if (sorted.any((p) => p.position == position))
        PlayerSection(
          title: '${position.label} (${position.code})',
          accent: accent,
          players: [
            for (final p in sorted)
              if (p.position == position) p,
          ],
        ),
  ];
}

// ── The rows ─────────────────────────────────────────────────────────────

class PositionRows extends StatelessWidget {
  const PositionRows({
    super.key,
    required this.sections,
    required this.cardLine,
    required this.onTap,
    this.showAverageAge = false,
    this.selecting = false,
    this.picked = const {},
  });

  final List<PlayerSection> sections;
  final CardLine cardLine;
  final ValueChanged<Player> onTap;

  /// "Avg age 22" on the right of each heading (Positions tab).
  final bool showAverageAge;

  /// FA select mode: pending players get a tick box, the others fade.
  final bool selecting;
  final Set<String> picked; // player IDs

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections)
          _Section(
            section: section,
            cardLine: cardLine,
            onTap: onTap,
            showAverageAge: showAverageAge,
            selecting: selecting,
            picked: picked,
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.cardLine,
    required this.onTap,
    required this.showAverageAge,
    required this.selecting,
    required this.picked,
  });

  final PlayerSection section;
  final CardLine cardLine;
  final ValueChanged<Player> onTap;
  final bool showAverageAge;
  final bool selecting;
  final Set<String> picked;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final players = section.players;
    const gap = 10.0;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Heading: coloured bar + "Defenders · 5" (+ "Avg age 22")
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 4, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: section.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      '${section.title} · ${players.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFCFE4FB)
                            : const Color(0xFF0B3F7A),
                      ),
                    ),
                  ),
                ),
                if (showAverageAge)
                  Text(
                    'Avg age ${section.averageAge}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          // Grid: 3 cards per row on a phone, more on wider screens.
          // Built row by row so all cards in a row have the same height.
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 170).floor().clamp(3, 5);
              return Column(
                children: [
                  for (var i = 0; i < players.length; i += columns)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var c = 0; c < columns; c++) ...[
                              if (c > 0) const SizedBox(width: gap),
                              Expanded(
                                child: i + c < players.length
                                    ? PlayerGridCard(
                                        player: players[i + c],
                                        cardLine: cardLine,
                                        selecting: selecting,
                                        selected:
                                            picked.contains(players[i + c].id),
                                        onTap: () => onTap(players[i + c]),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── One card ─────────────────────────────────────────────────────────────

/// Passport photo with #number and status, then the name and a small line
/// (see [CardLine]). Pending: gold border. Rejected: red border.
/// Selected (FA select mode): blue border and a tick.
class PlayerGridCard extends ConsumerWidget {
  const PlayerGridCard({
    super.key,
    required this.player,
    required this.cardLine,
    required this.onTap,
    this.selecting = false,
    this.selected = false,
  });

  final Player player;
  final CardLine cardLine;
  final VoidCallback onTap;
  final bool selecting;
  final bool selected;

  /// The small second line under the name.
  String get _line {
    final code = player.playerCode;
    final pos = player.position.code;
    final age = '${player.age} yrs';
    final approved = player.status == ApprovalStatus.approved;

    return switch (cardLine) {
      CardLine.squad => switch (player.status) {
          ApprovalStatus.approved => code == null ? pos : '$code · $pos',
          ApprovalStatus.pending => '$pos · awaiting FA',
          ApprovalStatus.rejected => '$pos · needs correcting',
        },
      CardLine.fa =>
        approved && code != null ? '$code · $pos' : '$pos · $age',
      CardLine.positionAndAge => '$pos · $age',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = player.status;
    final isPending = status == ApprovalStatus.pending;
    final isRejected = status == ApprovalStatus.rejected;
    final faded = selecting && !isPending;

    final borderColor = selected
        ? scheme.primary
        : isPending
            ? AppColors.ghanaGold
            : isRejected
                ? scheme.error
                : scheme.outline;
    final thickBorder = selected || isPending || isRejected;

    final (statusText, statusBg, statusInk) = switch (status) {
      ApprovalStatus.approved => (
          'Approved',
          isDark ? const Color(0xFF123D2B) : AppColors.approvedBg,
          isDark ? const Color(0xFF7BE3B0) : AppColors.approvedText,
        ),
      ApprovalStatus.pending => (
          'Pending',
          AppColors.ghanaGold,
          const Color(0xFF3A2C00),
        ),
      ApprovalStatus.rejected => (
          'Rejected',
          isDark ? const Color(0xFF4A1820) : AppColors.rejectedBg,
          isDark ? const Color(0xFFFF9DA6) : AppColors.rejectedText,
        ),
    };

    // The full 300×400 photo: the 96×128 thumbnail looks blurry this big.
    // Data saver: a silhouette instead of downloading photos.
    final photo = ref.watch(dataSaverProvider) ? null : player.photoUrl;
    final silhouette = ColoredBox(
      color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDCEAF9),
      child: Center(
        child: Icon(
          Icons.person,
          size: 48,
          color: isDark ? const Color(0xFF3F6690) : const Color(0xFF9DBBDD),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selecting ? selected : null,
      label: '${player.fullName}, number ${player.jerseyNo}, '
          '${player.position.label}, $statusText',
      excludeSemantics: true,
      child: Opacity(
        opacity: faded ? 0.45 : 1,
        child: Material(
          color: scheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor, width: thickBorder ? 2 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Photo (3:4) with the number and status on top
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      photo == null || photo.isEmpty
                          ? silhouette
                          : Image.network(
                              photo,
                              fit: BoxFit.cover,
                              // Sharper shrinking than the default (medium)
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, _, _) => silhouette,
                            ),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: _NumberChip(number: player.jerseyNo),
                      ),
                      if (selecting && isPending)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: _TickBox(selected: selected),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          color: statusBg,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          alignment: Alignment.center,
                          child: Text(
                            statusText.toUpperCase(),
                            style: TextStyle(
                              color: statusInk,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: isRejected && cardLine == CardLine.squad
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberChip extends StatelessWidget {
  const _NumberChip({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '#$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Round tick box in the corner of a card in select mode.
class _TickBox extends StatelessWidget {
  const _TickBox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.white.withValues(alpha: 0.9),
        border: Border.all(
          color: selected ? scheme.primary : const Color(0xFF9FB0C4),
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
          : null,
    );
  }
}
