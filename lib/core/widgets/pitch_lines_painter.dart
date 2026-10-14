import 'package:flutter/material.dart';

class PitchLinesPainter extends CustomPainter {
  const PitchLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dot = Paint()..color = Colors.white.withValues(alpha: 0.12);

    final centerX = size.width / 2;
    final halfwayY = size.height * 0.62;

    canvas.drawRect(
      Rect.fromLTRB(20, -40, size.width - 20, size.height + 40),
      line,
    );
    canvas.drawLine(
      Offset(20, halfwayY),
      Offset(size.width - 20, halfwayY),
      line,
    );
    canvas.drawCircle(Offset(centerX, halfwayY), 62, line);
    canvas.drawCircle(Offset(centerX, halfwayY), 3.5, dot);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(centerX, 0), width: 180, height: 110),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}