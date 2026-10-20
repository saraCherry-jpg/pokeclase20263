import 'package:flutter/material.dart';

class PokeballPainter extends CustomPainter {
  const PokeballPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.43;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final outline = Paint()
      ..color = const Color(0xFF252335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFF4F1E9));
    canvas.drawArc(
      bounds,
      3.14159265,
      3.14159265,
      true,
      Paint()..color = const Color(0xFFDC4545),
    );
    canvas.drawCircle(center, radius, outline);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      outline,
    );
    canvas.drawCircle(center, radius * 0.23, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius * 0.23, outline);
  }

  @override
  bool shouldRepaint(PokeballPainter oldDelegate) => false;
}
