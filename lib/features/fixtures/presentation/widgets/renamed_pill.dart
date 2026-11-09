import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

const _goldBg = Color(0xFFFFF6CC);
const _goldBgDark = Color(0xFF3D3410);
const _goldInk = Color(0xFF5C4700);
const _goldInkDark = Color(0xFFF5D25B);
const _goldRing = Color(0xFF8A6A00);

/// The gold "Previously Royal Unique FC" pill of a renamed team in a match
/// (JSc2, mockup R1–R3), with the team's mini crest so it's clear which
/// side it means. A tap opens or closes its [RenamedNote].
class RenamedPill extends StatelessWidget {
  const RenamedPill({
    super.key,
    required this.side,
    required this.previous,
    required this.open,
    required this.onTap,
    this.maxWidth = 190,
  });

  final FixtureSide side;
  final PreviousName previous;
  final bool open;
  final VoidCallback onTap;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? _goldInkDark : _goldInk;

    return Semantics(
      button: true,
      expanded: open,
      label:
          '${side.name}, previously ${previous.name}. '
          '${open ? 'Hide' : 'Show'} details',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        // A bigger tap area than the pill itself
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
            decoration: BoxDecoration(
              color: isDark ? _goldBgDark : _goldBg,
              borderRadius: BorderRadius.circular(99),
              border: open ? Border.all(color: _goldRing, width: 1.5) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TeamLogo(
                  label: side.crestLabel,
                  color: side.colour,
                  url: side.logoUrl,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Previously ${previous.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
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

/// The small gold note a [RenamedPill] opens, right under the match row or
/// card (no pop-up, no new screen): which team, its old name and when the
/// FA approved the new one.
class RenamedNote extends StatelessWidget {
  const RenamedNote({
    super.key,
    required this.side,
    required this.previous,
    required this.isHome,
    required this.onClose,
  });

  final FixtureSide side;
  final PreviousName previous;

  /// The renamed team plays on the left (home) or the right (away)
  final bool isHome;
  final VoidCallback onClose;

  /// "Royal Stars FC B (left), the juvenile side of Royal Stars FC, was
  /// called Royal Unique FC B until Mon 9 Nov 2026, when its club was
  /// renamed." or "Royal Stars FC (right) was called Royal Unique FC until
  /// Mon 9 Nov 2026. Same club: its players and matches carry over."
  static TextSpan text(FixtureSide side, PreviousName previous, bool isHome) {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    final until = previous.until;
    final when = until == null
        ? ''
        : ' until ${formatShortDate(until)} ${until.toLocal().year}';
    final where = isHome ? 'left' : 'right';
    final bSide = side.isBSide && side.name.endsWith(' B');
    return TextSpan(
      children: [
        TextSpan(text: side.name, style: bold),
        TextSpan(text: ' ($where)'),
        if (bSide)
          TextSpan(
            text:
                ', the juvenile side of '
                '${side.name.substring(0, side.name.length - 2)},',
          ),
        const TextSpan(text: ' was called '),
        TextSpan(text: previous.name, style: bold),
        TextSpan(
          text: bSide
              ? '$when, when its club was renamed.'
              : '$when. Same club: its players and matches carry over.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? _goldInkDark : const Color(0xFF3D3000);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: isDark ? _goldBgDark : _goldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.history_rounded, size: 18, color: ink),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              text(side, previous, isHome),
              style: TextStyle(color: ink, fontSize: 12, height: 1.45),
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: ink,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
