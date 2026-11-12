import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/widgets/flag_stripe.dart';
import 'package:gedfa_connect/features/onboarding/data/intro_seen.dart';
import 'package:gedfa_connect/features/onboarding/domain/intro_pages.dart';

/// R-b: the three intro screens, shown once per phone before Log in.
/// Skip (screens 1–2) and Get started (screen 3) both remember it and go to
/// Log in.
class IntroScreen extends ConsumerWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntroView(
      onDone: () async {
        await ref.read(introSeenProvider.notifier).markSeen();
        if (context.mounted) context.go(Routes.login);
      },
    );
  }
}

/// Phones and laptops from this width get the intro as a card in the middle.
const _laptopWidth = 840.0;

/// The intro's look on its own, so tests can build it without Firebase.
class IntroView extends StatefulWidget {
  const IntroView({super.key, required this.onDone});

  /// Skip or Get started.
  final VoidCallback onDone;

  @override
  State<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<IntroView> {
  final _pages = PageController();
  int _page = 0;

  bool get _last => _page == introPages.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark ? AppColors.darkHeroGradient : AppColors.heroGradient,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: gradient,
          child: LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth < _laptopWidth) return _content(isDark);
              // Laptop: the same intro as a card in the middle of the blue.
              return Center(
                child: Container(
                  width: 420,
                  height: math.min(760, box.maxHeight - 48),
                  clipBehavior: Clip.antiAlias,
                  decoration: gradient.copyWith(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 40,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: _content(isDark, laptop: true),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(bool isDark, {bool laptop = false}) {
    final top = laptop ? 0.0 : MediaQuery.paddingOf(context).top;
    final bottom = laptop ? 0.0 : MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        PageView.builder(
          controller: _pages,
          itemCount: introPages.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => _IntroPageView(
            page: introPages[i],
            active: i == _page,
            topPadding: top,
            bottomPadding: bottom,
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: FlagStripe(height: 5),
        ),
        if (!_last)
          Positioned(
            top: top + 14,
            right: 16,
            child: _SkipButton(onPressed: widget.onDone),
          ),
        Positioned(
          left: 22,
          right: 22,
          bottom: bottom + 22,
          child: _Controls(
            page: _page,
            count: introPages.length,
            laptop: laptop,
            onBack: () => _goTo(_page - 1),
            onNext: () => _goTo(_page + 1),
            onStart: widget.onDone,
          ),
        ),
      ],
    );
  }
}

/// The bottom card's height taken by the dots and the buttons, so the text
/// above them never runs underneath.
const _controlsHeight = 116.0;

class _IntroPageView extends StatelessWidget {
  const _IntroPageView({
    required this.page,
    required this.active,
    required this.topPadding,
    required this.bottomPadding,
  });

  final IntroPage page;
  final bool active;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: '${page.kicker}. ${page.title}',
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: _Picture(page: page, active: active),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              22,
              26,
              22,
              _controlsHeight + bottomPadding,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  page.kicker.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AccentTone.gold.foreground(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  page.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  page.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    height: 1.55,
                    color: scheme.onSurfaceVariant,
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

/// The top half: a faint pitch, the big white circle with the page's icon
/// and three little cards. They float in (scale + fade) when the page
/// becomes the current one; not when the phone asks for less motion.
class _Picture extends StatelessWidget {
  const _Picture({required this.page, required this.active});

  final IntroPage page;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final shown = active || reduceMotion;

    Widget floatIn(Widget child, {int delay = 0}) => AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: duration + Duration(milliseconds: reduceMotion ? 0 : delay),
      curve: Curves.easeOut,
      child: AnimatedScale(
        scale: shown ? 1 : 0.7,
        duration: duration + Duration(milliseconds: reduceMotion ? 0 : delay),
        curve: Curves.easeOutBack,
        child: child,
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        // Small phones: the circle shrinks so it never covers the cards.
        final orb = math.min(150.0, h * 0.5);
        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 40, 26, 10),
                child: CustomPaint(painter: _PitchPainter()),
              ),
            ),
            Center(
              child: floatIn(_Orb(icon: page.icon, size: orb)),
            ),
            for (final (i, chip) in page.chips.indexed)
              Positioned(
                top: chip.top == null ? null : chip.top! * h,
                bottom: chip.bottom == null ? null : chip.bottom! * h,
                left: chip.left,
                right: chip.right,
                child: floatIn(_FloatingChip(chip: chip), delay: 80 * (i + 1)),
              ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final core = size * 0.75;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0x1AFFFFFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: core,
        height: core,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: core / 2, color: AppColors.deepBlue),
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({required this.chip});

  final IntroChip chip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x38000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chip.icon, size: 18, color: chip.tone.foreground(isDark)),
            const SizedBox(width: 6),
            Text(
              chip.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faint pitch lines behind the circle: the outline, the halfway line and
/// the centre circle.
class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26)),
      line,
    );
    final mid = size.height / 2;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), line);
    canvas.drawCircle(Offset(size.width / 2, mid), 45, line);
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.9),
        backgroundColor: const Color(0x1FFFFFFF),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: const Text('Skip'),
    );
  }
}

/// The dots, then → (screens 1–2) or Get started (screen 3). On a laptop
/// there is also ← (no swiping with a mouse).
class _Controls extends StatelessWidget {
  const _Controls({
    required this.page,
    required this.count,
    required this.laptop,
    required this.onBack,
    required this.onNext,
    required this.onStart,
  });

  final int page;
  final int count;
  final bool laptop;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final last = page == count - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Screen ${page + 1} of $count',
          child: Row(
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 6),
                  width: i == page ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == page
                        ? AppColors.ghanaGold
                        : AccentTone.grey.background(isDark),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: Row(
            children: [
              if (laptop && page > 0) ...[
                IconButton.outlined(
                  onPressed: onBack,
                  tooltip: 'Back',
                  iconSize: 22,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(54, 54),
                    side: BorderSide(color: scheme.outline, width: 1.5),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
              ],
              if (last)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onStart,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Get started'),
                  ),
                )
              else ...[
                const Spacer(),
                IconButton.filled(
                  onPressed: onNext,
                  tooltip: 'Next',
                  iconSize: 24,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(54, 54),
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
