import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/startup_gate.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/widgets/flag_stripe.dart';
import 'package:gedfa_connect/core/widgets/loading.dart';
import 'package:gedfa_connect/core/widgets/pitch_lines_painter.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:gedfa_connect/features/dashboard/data/dashboard_providers.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/officials/data/officials_repository.dart';
import 'package:gedfa_connect/features/onboarding/data/intro_seen.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// L1 (M1) and R-a2: what a user sees when the app opens. The logo grows
/// from where the phone's splash left it, breathes, and the app moves on
/// once at least [startupMinimum] has passed and the next screen is ready
/// (fonts and pictures loaded; the account loaded). Then the logo glides
/// into Log in (RU1), or the next screen fades in (the intro, your Home).
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  /// False when the start-up screen shows again later (after Log in, while
  /// your role loads): then the logo is big at once and there is no gate.
  late final bool _opening = !ref.read(startupGateProvider);

  bool _started = false;

  /// The minimum time has passed and the fonts and pictures are loaded.
  bool _ready = false;
  bool _gliding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opening && !_started) {
      _started = true;
      unawaited(_getReady());
    }
  }

  Future<void> _getReady() async {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    await Future.wait([
      Future<void>.delayed(reduceMotion ? Duration.zero : startupMinimum),
      _loadFontsAndPictures(),
    ]);
    if (!mounted) return;
    _ready = true;
    _leaveIfReady();
  }

  /// The next screen's fonts (Poppins) and pictures, so it doesn't draw
  /// with the wrong font and then jump. Never blocks the app: after 6 s
  /// (no connection) it goes on anyway.
  Future<void> _loadFontsAndPictures() async {
    try {
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/gedfa_logo.png'),
          context,
        ),
        precacheImage(const AssetImage('assets/images/google_g.png'), context),
        GoogleFonts.pendingFonts(),
      ]).timeout(const Duration(seconds: 6));
    } catch (_) {
      // A font or picture that didn't load is drawn when it arrives.
    }
  }

  /// Once ready and the app knows who is signed in: glide into Log in, or
  /// open the gate (the router then fades in the intro or your Home).
  void _leaveIfReady() {
    if (!_ready || _gliding || ref.read(startupGateProvider)) return;
    final auth = ref.read(authStateProvider);
    if (!auth.hasValue) return; // still finding out: wait
    final goingToLogin = auth.value == null && ref.read(introSeenProvider);
    if (goingToLogin) {
      setState(() => _gliding = true); // StartupView calls _glided after
    } else {
      ref.read(startupGateProvider.notifier).open();
    }
  }

  void _glided() {
    ref.read(startupGateProvider.notifier).open(glideToLogin: true);
  }

  /// Your Home's first data starts loading during the breath (RU2), so Home
  /// opens filled in. These stay loaded after the start-up screen.
  void _warmUp(UserRole? role) {
    switch (role) {
      case UserRole.faAdmin:
        ref.listen(faWaitingProvider, (_, _) {});
        ref.listen(dashboardStatsProvider, (_, _) {});
      case UserRole.teamAdmin:
        ref.listen(myTeamProvider, (_, _) {});
        ref.listen(myFixturesProvider, (_, _) {});
      case UserRole.referee:
        ref.listen(myAppointmentsProvider, (_, _) {});
        ref.listen(seasonFixturesProvider, (_, _) {});
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider);
    final failed = appUser.hasError && !appUser.isLoading;
    if (_opening) {
      ref.listen(authStateProvider, (_, _) => _leaveIfReady());
      _warmUp(appUser.value?.role);
    }

    return StartupView(
      failed: failed,
      onRetry: () => ref.invalidate(appUserProvider),
      entrance: _opening,
      glideToLogin: _gliding,
      onGlided: _glided,
    );
  }
}

/// The friendly lines, in order, after the greeting (Isaac, 12 Nov 2026).
const startupLines = [
  'Warming up…',
  'Pumping the balls…',
  'Checking the team sheets…',
  'Marking the pitch lines…',
  'Calling the players in…',
  'Almost kick-off…',
];

/// "Good morning!" / "Good afternoon!" / "Good evening!" for [hour] (0–23).
String greetingFor(int hour) {
  if (hour < 12) return 'Good morning!';
  if (hour < 17) return 'Good afternoon!';
  return 'Good evening!';
}

/// How wide the phone's own splash draws the logo (R-a: `splash.png`, 728 px
/// at 4×), so the start-up screen starts from exactly there.
const splashLogoWidth = 182.0;

/// The logo's height for a width (the picture is 728 × 237).
double _logoHeight(double width) => width * 237 / 728;

/// The start-up look on its own (L1, L1b slow, L1c failed; R-a2 grow,
/// breathe, glide), so tests can build it without Firebase.
class StartupView extends StatefulWidget {
  const StartupView({
    super.key,
    this.failed = false,
    this.onRetry,
    this.entrance = true,
    this.glideToLogin = false,
    this.onGlided,
  });

  final bool failed;
  final VoidCallback? onRetry;

  /// Grow from the splash's small logo (the app opening). False: big at once.
  final bool entrance;

  /// Becomes true when the app goes on to Log in: the logo glides up into
  /// Log in's header, then [onGlided].
  final bool glideToLogin;
  final VoidCallback? onGlided;

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView>
    with TickerProviderStateMixin {
  // All made in initState, not lazily: a lazy one first made in dispose()
  // (the failed screen never breathes) crashes.
  late final AnimationController _grow;
  late final AnimationController _breathe;
  late final AnimationController _glide;

  late final List<String> _lines = [
    greetingFor(DateTime.now().hour),
    ...startupLines,
  ];
  int _line = 0;
  Timer? _timer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _grow =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
          value: widget.entrance ? 0 : 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _startBreathing();
        });
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      // The last line stays: the app is nearly ready.
      if (mounted && _line < _lines.length - 1) setState(() => _line++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _grow.value = 1;
      _breathe.stop();
    } else if (_grow.value == 0 && !_grow.isAnimating) {
      _grow.forward();
    } else if (_grow.isCompleted) {
      _startBreathing();
    }
  }

  @override
  void didUpdateWidget(StartupView old) {
    super.didUpdateWidget(old);
    if (widget.glideToLogin && !old.glideToLogin) _startGlide();
    if (widget.failed) _breathe.stop();
    if (!widget.failed && old.failed) _startBreathing();
  }

  void _startBreathing() {
    if (_reduceMotion || widget.failed || widget.glideToLogin) return;
    if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
  }

  Future<void> _startGlide() async {
    _breathe.stop();
    if (_reduceMotion) {
      _glide.value = 1;
    } else {
      await _glide.forward();
    }
    if (mounted) widget.onGlided?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _grow.dispose();
    _breathe.dispose();
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.paddingOf(context).top;
    final pageColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      // The phone's splash colour, so the first frame matches it exactly
      backgroundColor: AppColors.heroDark,
      body: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: Listenable.merge([_grow, _breathe, _glide]),
          builder: (context, _) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final grow = Curves.easeOutCubic.transform(_grow.value);
            final glide = Curves.easeInOutCubic.transform(_glide.value);
            final breath = Curves.easeInOut.transform(_breathe.value);

            // The logo: splash size in the middle → big, a little higher →
            // Log in's header (RU1).
            final restWidth = math.min(280.0, w - 60);
            final logoWidth = lerpDouble(
              lerpDouble(splashLogoWidth, restWidth, grow),
              AuthScaffold.loginLogoWidth,
              glide,
            )!;
            final logoCenter = lerpDouble(
              lerpDouble(h / 2, h * 0.40, grow),
              AuthScaffold.heroCenterY(top, AuthScaffold.loginHeroHeight),
              glide,
            )!;
            final breathing = breath * (1 - glide);

            // The stripe: slides down at the top, then settles under Log
            // in's header.
            final headerBottom = top + AuthScaffold.loginHeroHeight;
            final stripeTop = lerpDouble(-6 * (1 - grow), headerBottom, glide)!;
            final stripeHeight = lerpDouble(
              6,
              AuthScaffold.stripeHeight,
              glide,
            )!;

            final wordsShown =
                Curves.easeOut.transform(
                  ((_grow.value - 0.4) / 0.6).clamp(0, 1),
                ) *
                (1 - glide);
            final wordsTop = h * 0.40 + _logoHeight(restWidth) / 2 + 26;

            return Stack(
              children: [
                // The blue gradient fades in over the splash's navy
                Positioned.fill(
                  child: Opacity(
                    opacity: grow * (1 - glide),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: dark
                              ? AppColors.darkHeroGradient
                              : AppColors.heroGradient,
                        ),
                      ),
                    ),
                  ),
                ),
                // Gliding to Log in: its pitch lines and its page colour
                if (glide > 0) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: headerBottom,
                    child: Opacity(
                      opacity: glide,
                      child: const CustomPaint(painter: PitchLinesPainter()),
                    ),
                  ),
                  Positioned(
                    top: headerBottom + AuthScaffold.stripeHeight,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: glide,
                      child: ColoredBox(color: pageColor),
                    ),
                  ),
                ],
                Positioned(
                  top: stripeTop,
                  left: 0,
                  right: 0,
                  child: FlagStripe(height: stripeHeight),
                ),
                Positioned(
                  left: (w - logoWidth) / 2,
                  top: logoCenter - _logoHeight(logoWidth) / 2,
                  width: logoWidth,
                  child: Transform.scale(
                    scale: 1 + 0.05 * breathing,
                    child: _Logo(width: logoWidth, glow: breathing),
                  ),
                ),
                Positioned(
                  top: wordsTop,
                  left: 30,
                  right: 30,
                  child: Opacity(
                    opacity: wordsShown,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - grow)),
                      child: _Words(
                        failed: widget.failed,
                        line: _lines[_line],
                        lineKey: _line,
                        onRetry: widget.onRetry,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 22,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: grow * (1 - glide),
                    child: Text(
                      'Season ${Season.label(Season.current)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The logo, with a soft gold glow behind it that comes and goes with the
/// breath ([glow] 0–1).
class _Logo extends StatelessWidget {
  const _Logo({required this.width, required this.glow});

  final double width;
  final double glow;

  static const _asset = 'assets/images/gedfa_logo.png';

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      _asset,
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'GEDFA, Gomoa East District Football Association',
      errorBuilder: (_, _, _) => const Text(
        'GEDFA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (glow <= 0.01) return logo;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.45 * glow,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Image.asset(
                _asset,
                width: width,
                fit: BoxFit.contain,
                color: AppColors.ghanaGold,
                colorBlendMode: BlendMode.srcIn,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        logo,
      ],
    );
  }
}

/// Under the logo: the name, then the friendly line and the gold bar (or
/// "We couldn't reach the pitch" with Try again).
class _Words extends StatelessWidget {
  const _Words({
    required this.failed,
    required this.line,
    required this.lineKey,
    required this.onRetry,
  });

  final bool failed;
  final String line;
  final int lineKey;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Gedfa Connect',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 30),
        if (failed) ...[
          const Text(
            "We couldn't reach the pitch.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "We couldn't load your account. Check your connection "
            'and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(160, 44),
              foregroundColor: white,
              side: const BorderSide(color: Colors.white70, width: 1.5),
            ),
            child: const Text('Try again'),
          ),
        ] else ...[
          SizedBox(
            height: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: Text(
                line,
                key: ValueKey(lineKey),
                style: const TextStyle(
                  color: white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: const SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                minHeight: 4,
                color: AppColors.ghanaGold,
                backgroundColor: Color(0x2EFFFFFF),
              ),
            ),
          ),
          const SlowNote(child: _SlowBox()),
        ],
      ],
    );
  }
}

class _SlowBox extends StatelessWidget {
  const _SlowBox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  slowLoadingText,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
