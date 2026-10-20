import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';

/// One tab in [CountTabs].
class CountTab<T> {
  const CountTab({
    required this.value,
    required this.label,
    required this.count,
    this.highlight = false,
  });

  final T value;
  final String label;
  final int count;

  /// Gold count bubble (e.g. Pending: things waiting for you).
  final bool highlight;
}

/// Tabs in a rounded grey track, like the mockup: the selected tab becomes a
/// white (dark mode: blue-grey) rounded square, and each tab shows its count
/// in a small bubble. Used for Pending / Rejected / Approved.
class CountTabs<T> extends StatelessWidget {
  const CountTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final List<CountTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFDCE6F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _TabButton(
                tab: tabs[i],
                selected: tabs[i].value == selected,
                onTap: () => onChanged(tabs[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabButton<T> extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final CountTab<T> tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // Colours of the tab itself
    final background = selected
        ? (isDark ? const Color(0xFF24476E) : Colors.white)
        : Colors.transparent;
    final textColor = selected
        ? (isDark ? AppColors.darkInk : const Color(0xFF0B3F7A))
        : scheme.onSurfaceVariant;

    // Colours of the count bubble
    final bubbleColor = tab.highlight
        ? AppColors.ghanaGold
        : (isDark ? AppColors.darkBorder : const Color(0xFFC9D6E6));
    final bubbleText = tab.highlight
        ? const Color(0xFF3A2C00)
        : (isDark ? AppColors.darkInk : AppColors.ink);

    return Semantics(
      selected: selected,
      button: true,
      label: '${tab.label}, ${tab.count}',
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(11),
        elevation: selected && !isDark ? 1 : 0,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${tab.count}',
                    style: TextStyle(
                      color: bubbleText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      height: 1,
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
