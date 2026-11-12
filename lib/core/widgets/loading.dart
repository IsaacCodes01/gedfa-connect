import 'dart:async';

import 'package:flutter/material.dart';

/// M1: the shared look for "the app is GETTING something for you to read".
/// Words start with Getting / Loading / Finding ("Getting your squad…").
/// Saving what the user did is M2, in `sending.dart`.

/// How long before a wait says the connection seems slow (M1, M2).
const slowAfter = Duration(seconds: 8);

/// The line shown when a wait passes [slowAfter].
const slowLoadingText = 'Still working, your connection seems slow.';

/// Shows [child] (the slow note) only after [after] has passed. Used by every
/// loading and sending widget so they all say "slow" at the same moment.
class SlowNote extends StatefulWidget {
  const SlowNote({super.key, required this.child, this.after = slowAfter});

  final Widget child;
  final Duration after;

  @override
  State<SlowNote> createState() => _SlowNoteState();
}

class _SlowNoteState extends State<SlowNote> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.after, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: _slow ? widget.child : const SizedBox(width: double.infinity),
    );
  }
}

/// L2a: a rolling football with a ring around it.
class RollingBall extends StatefulWidget {
  const RollingBall({super.key, this.size = 44});

  final double size;

  @override
  State<RollingBall> createState() => _RollingBallState();
}

class _RollingBallState extends State<RollingBall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = widget.size;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          RotationTransition(
            turns: _spin,
            child: Icon(
              Icons.sports_soccer_rounded,
              size: size * 0.6,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// L2a: a whole page (or a big area) loading. Give it the screen's own words:
/// `LoadingView(message: 'Loading the match…')`.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RollingBall(),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            SlowNote(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  slowLoadingText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L2c: one card (or one line) loading: a small spinner and the words.
class LoadingLine extends StatelessWidget {
  const LoadingLine({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SlowNote(
            child: Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Text(
                slowLoadingText,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// L2b: a grey box that shimmers, in the shape of what is coming.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  /// A circle (a player's photo or a crest).
  const SkeletonBox.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = 999;

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF1B2F4B) : const Color(0xFFE3EAF2);
    final light = dark ? const Color(0xFF24406A) : const Color(0xFFF3F7FB);

    return AnimatedBuilder(
      animation: _shine,
      builder: (context, _) {
        // The bright band moves from right to left across the box.
        final t = 1 - _shine.value * 2;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [base, light, base],
            ),
          ),
        );
      },
    );
  }
}

/// L2b: a card of shimmering rows (photo, two lines, a pill), for lists and
/// dashboards, with the screen's words above it.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.message = 'Loading…',
    this.rows = 5,
    this.circle = true,
    this.padding = const EdgeInsets.all(16),
  });

  final String message;
  final int rows;

  /// A round picture at the start of each row (players, teams).
  final bool circle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const widths = [0.7, 0.6, 0.75, 0.55, 0.65];

    return ListView(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        LoadingLine(message: message),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < rows; i++) ...[
                  if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        if (circle) ...[
                          const SkeletonBox.circle(size: 44),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(
                                  width:
                                      box.maxWidth * widths[i % widths.length],
                                  height: 12,
                                ),
                                const SizedBox(height: 8),
                                SkeletonBox(
                                  width:
                                      box.maxWidth *
                                      widths[i % widths.length] *
                                      0.55,
                                  height: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const SkeletonBox(width: 52, height: 20, radius: 99),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
