import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';

/// The dashboard's white (dark: navy) card: soft border, round corners
/// and a light shadow (2.12).
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Optional: the whole card opens something.
  final VoidCallback? onTap;

  static const _radius = 20.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: dashboardBorder(context)),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          else ...[
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

Color dashboardBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.darkCardBorder
    : AppColors.cardBorder;

/// The track behind bars and progress lines.
Color dashboardTrack(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF1B2F4B)
    : const Color(0xFFE6EDF5);

/// A coloured square with an icon (the start of each row and tile).
class AccentIcon extends StatelessWidget {
  const AccentIcon({super.key, required this.icon, required this.tone});

  final IconData icon;
  final AccentTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: tone.background(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: tone.foreground(isDark)),
    );
  }
}

/// "Needs you" … "33 waiting": a section heading with an optional grey
/// note, or a blue link ([onTap]) on the right.
class DashboardSectionTitle extends StatelessWidget {
  const DashboardSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
    this.top = 20,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  /// Space above (the first section on the page has less).
  final double top;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = trailing == null
        ? null
        : Text(
            trailing!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: onTap == null ? 12 : 12.5,
              fontWeight: FontWeight.w600,
              color: onTap == null ? scheme.onSurfaceVariant : scheme.primary,
            ),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 10),
      // Title on the left, note on the right. On a very narrow screen
      // both end in "…" instead of overflowing (the title keeps more room).
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 10),
            Flexible(
              flex: 2,
              child: onTap == null
                  ? note
                  : InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: note,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How long the numbers count up and the bars grow when Home opens.
/// Nothing moves when the phone asks for less motion.
Duration dashboardMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 600);

/// A number that counts up from 0 the first time it shows, then glides
/// to the new value when it changes (live numbers).
class CountUpText extends StatelessWidget {
  const CountUpText(this.value, {super.key, required this.style, this.format});

  final int value;
  final TextStyle style;

  /// e.g. thousands with commas. Default: the plain number.
  final String Function(int value)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: dashboardMotion(context),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) {
        final n = v.round();
        return Text(format == null ? '$n' : format!(n), style: style);
      },
    );
  }
}

/// A rounded bar on a grey track that grows to [fraction] (0 to 1).
class GrowingBar extends StatelessWidget {
  const GrowingBar({
    super.key,
    required this.fraction,
    required this.colors,
    this.height = 10,
  });

  final double fraction;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        color: dashboardTrack(context),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
          duration: dashboardMotion(context),
          curve: Curves.easeOutCubic,
          builder: (_, f, _) => FractionallySizedBox(
            widthFactor: f,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(colors: colors),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
