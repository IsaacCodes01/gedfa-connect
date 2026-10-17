import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:gedfa_connect/features/teams/domain/kit.dart';

class KitPreview extends StatelessWidget {
  const KitPreview({
    super.key,
    required this.kit,
    this.width = 88,
    this.semanticLabel,
  });

  final Kit kit;
  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final outline =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);
    final size = Size(width, width * 1.3);

    final painting = CustomPaint(
      key: ValueKey(kit.toMap().toString()),
      size: size,
      painter: _KitPainter(kit: kit, outline: outline),
    );

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox.fromSize(
        size: size,
        child: reduceMotion
            ? painting
                : AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                // Keep the old kit underneath while the new one fades in on top
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.center,
                  children: [
                    ...previous,
                    ?current,
                  ],
                ),
                transitionBuilder: (child, animation) {
                  // The old kit stays solid; only the new kit fades in
                  if (child.key != painting.key) return child;
                  return FadeTransition(opacity: animation, child: child);
                },
                child: painting,
              ),
      ),
    );
  }
}

class _KitPainter extends CustomPainter {
  _KitPainter({required this.kit, required this.outline});

  final Kit kit;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Draw on an imaginary 100 × 130 grid, scaled to the real size.
    canvas.scale(size.width / 100, size.height / 130);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..color = outline;

    // ---------- Shirt ----------
    final shirt = Path()
      ..moveTo(35, 4)
      ..quadraticBezierTo(50, 14, 65, 4)
      ..lineTo(86, 10)
      ..lineTo(100, 28)
      ..lineTo(88, 36)
      ..lineTo(80, 28)
      ..lineTo(80, 70)
      ..lineTo(20, 70)
      ..lineTo(20, 28)
      ..lineTo(12, 36)
      ..lineTo(0, 28)
      ..lineTo(14, 10)
      ..close();

    canvas.drawPath(shirt, Paint()..color = kit.primary);

    canvas.save();
    canvas.clipPath(shirt);
    final second = kit.secondary;
    if (kit.needsSecondary && second != null) {
      _drawPattern(canvas, Paint()..color = second);
    }
    final trim = kit.trim;
    if (trim != null) {
      _drawShirtTrims(canvas, trim);
    }
    canvas.restore();
    canvas.drawPath(shirt, stroke);

    // ---------- Shorts ----------
    final shorts = Path()
      ..moveTo(21, 74)
      ..lineTo(79, 74)
      ..lineTo(83, 100)
      ..lineTo(54, 100)
      ..lineTo(50, 90)
      ..lineTo(46, 100)
      ..lineTo(17, 100)
      ..close();
    canvas.drawPath(shorts, Paint()..color = kit.shorts);

    if (trim != null && kit.shortsStripe) {
      canvas.save();
      canvas.clipPath(shorts);
      final band = Paint()..color = trim;
      canvas.drawPath(
        Path()
          ..moveTo(21, 74)
          ..lineTo(26, 74)
          ..lineTo(22, 100)
          ..lineTo(17, 100)
          ..close(),
        band,
      );
      canvas.drawPath(
        Path()
          ..moveTo(74, 74)
          ..lineTo(79, 74)
          ..lineTo(83, 100)
          ..lineTo(78, 100)
          ..close(),
        band,
      );
      canvas.restore();
    }
    canvas.drawPath(shorts, stroke);

    // ---------- Socks ----------
    for (final left in [24.0, 60.0]) {
      final sock = RRect.fromLTRBR(
        left, 104, left + 16, 128, const Radius.circular(3),
      );
      canvas.drawRRect(sock, Paint()..color = kit.socks);
      canvas.drawRRect(sock, stroke);
    }

    canvas.restore();
  }

  void _drawPattern(Canvas canvas, Paint paint) {
    switch (kit.pattern) {
      case KitPattern.plain:
        break;
      case KitPattern.stripes:
        for (double x = 6; x < 100; x += 16) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 8, 70), paint);
        }
      case KitPattern.hoops:
        for (double y = 14; y < 70; y += 16) {
          canvas.drawRect(Rect.fromLTWH(0, y, 100, 8), paint);
        }
      case KitPattern.halves:
        canvas.drawRect(const Rect.fromLTWH(50, 0, 50, 70), paint);
      case KitPattern.sash:
        final sash = Path()
          ..moveTo(14, 4)
          ..lineTo(30, 4)
          ..lineTo(86, 70)
          ..lineTo(70, 70)
          ..close();
        canvas.drawPath(sash, paint);
    }
  }

  void _drawShirtTrims(Canvas canvas, Color trim) {
    final line = Paint()
      ..color = trim
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (kit.shoulderStripes) {
      line.strokeWidth = 1.6;
      for (final d in [3.0, 6.0, 9.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(35, 4 + d)
            ..lineTo(14, 10 + d)
            ..lineTo(0, 28 + d),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(65, 4 + d)
            ..lineTo(86, 10 + d)
            ..lineTo(100, 28 + d),
          line,
        );
      }
    }

    if (kit.collarAndCuffs) {
      line.strokeWidth = 5;
      canvas.drawPath(
        Path()
          ..moveTo(35, 4)
          ..quadraticBezierTo(50, 14, 65, 4),
        line,
      );
      canvas.drawLine(const Offset(0, 28), const Offset(12, 36), line);
      canvas.drawLine(const Offset(100, 28), const Offset(88, 36), line);
    }
  }

  @override
  bool shouldRepaint(_KitPainter old) =>
      old.kit != kit || old.outline != outline;
}

class KitOutline extends StatelessWidget {
  const KitOutline({super.key, required this.color, this.width = 70});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 1.3),
      painter: _KitOutlinePainter(color),
    );
  }
}

class _KitOutlinePainter extends CustomPainter {
  _KitOutlinePainter(this.color);

  final Color color;

  Path _dashed(Path source, {double dash = 6, double gap = 5}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        result.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gap;
      }
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 130);

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final shirt = Path()
      ..moveTo(35, 4)
      ..quadraticBezierTo(50, 14, 65, 4)
      ..lineTo(86, 10)
      ..lineTo(100, 28)
      ..lineTo(88, 36)
      ..lineTo(80, 28)
      ..lineTo(80, 70)
      ..lineTo(20, 70)
      ..lineTo(20, 28)
      ..lineTo(12, 36)
      ..lineTo(0, 28)
      ..lineTo(14, 10)
      ..close();
    final shorts = Path()
      ..moveTo(21, 74)
      ..lineTo(79, 74)
      ..lineTo(83, 100)
      ..lineTo(54, 100)
      ..lineTo(50, 90)
      ..lineTo(46, 100)
      ..lineTo(17, 100)
      ..close();

    canvas.drawPath(_dashed(shirt), line);
    canvas.drawPath(_dashed(shorts), line);

    // The plus sign in the middle of the shirt
    line.strokeWidth = 3;
    canvas.drawLine(const Offset(50, 30), const Offset(50, 54), line);
    canvas.drawLine(const Offset(38, 42), const Offset(62, 42), line);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_KitOutlinePainter old) => old.color != color;
}