import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/widgets/flag_stripe.dart';
import 'package:gedfa_connect/core/widgets/loading.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';

/// L1 (M1): what a user sees while the app finds out who is signed in and
/// loads their account. The GEDFA logo breathes, a gold bar slides and a
/// friendly line changes every 2 seconds.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider);
    final failed = appUser.hasError && !appUser.isLoading;

    return StartupView(
      failed: failed,
      onRetry: () => ref.invalidate(appUserProvider),
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

/// The start-up look on its own (L1, L1b slow, L1c failed), so tests can
/// build it without Firebase.
class StartupView extends StatefulWidget {
  const StartupView({super.key, this.failed = false, this.onRetry});

  final bool failed;
  final VoidCallback? onRetry;

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView>
    with SingleTickerProviderStateMixin {
  // Made in initState, not lazily: a lazy one first made in dispose()
  // (the failed screen never breathes) crashes.
  late final AnimationController _breathe;

  late final List<String> _lines = [
    greetingFor(DateTime.now().hour),
    ...startupLines,
  ];
  int _line = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      // The last line stays: the app is nearly ready.
      if (mounted && _line < _lines.length - 1) setState(() => _line++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final failed = widget.failed;
    const white = Colors.white;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [
                    Color(0xFF081A30),
                    Color(0xFF0F2A4A),
                    Color(0xFF15467F),
                  ]
                : const [
                    AppColors.heroDark,
                    AppColors.deepBlue,
                    AppColors.brandBlue,
                  ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(top: 0, left: 0, right: 0, child: FlagStripe()),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: failed
                          ? const AlwaysStoppedAnimation(1)
                          : Tween(begin: 1.0, end: 1.05).animate(
                              CurvedAnimation(
                                parent: _breathe,
                                curve: Curves.easeInOut,
                              ),
                            ),
                      child: const _Logo(),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Gedfa Connect',
                      style: TextStyle(
                        color: white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 34),
                    if (failed) ...[
                      const Text(
                        "We couldn't reach the pitch.",
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
                        onPressed: widget.onRetry,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(160, 44),
                          foregroundColor: white,
                          side: const BorderSide(
                            color: Colors.white70,
                            width: 1.5,
                          ),
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
                            _lines[_line],
                            key: ValueKey(_line),
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
                ),
              ),
            ),
            Positioned(
              bottom: 22,
              left: 0,
              right: 0,
              child: Text(
                'Season ${Season.label(Season.current)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  // The logo's letters are white and it already says "Gomoa East District
  // Football Association", so it sits straight on the blue.
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Image.asset(
        'assets/images/gedfa_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text(
          'GEDFA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
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
