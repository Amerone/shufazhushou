import 'package:flutter/material.dart';

class BrushStrokeDivider extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final Alignment alignment;
  final EdgeInsetsGeometry? padding;

  const BrushStrokeDivider({
    super.key,
    this.width = 132,
    this.height = 12,
    required this.color,
    this.alignment = Alignment.centerLeft,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: CustomPaint(
          size: Size(width, height),
          painter: _BrushStrokePainter(color: color),
        ),
      ),
    );
  }
}

class _BrushStrokePainter extends CustomPainter {
  final Color color;

  const _BrushStrokePainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.92),
          color.withValues(alpha: 0.78),
          color.withValues(alpha: 0.38),
          Colors.transparent,
        ],
        stops: const [0.0, 0.34, 0.72, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.08,
        size.height * 0.08,
        size.width * 0.2,
        size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.76,
        size.width * 0.5,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.18,
        size.width * 0.82,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.6,
        size.width,
        size.height * 0.44,
      )
      ..lineTo(size.width, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.94,
        size.width * 0.74,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.6,
        size.width * 0.44,
        size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height,
        size.width * 0.08,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.02,
        size.height * 0.7,
        0,
        size.height * 0.84,
      )
      ..close();

    canvas.drawPath(path, strokePaint);

    final splatterPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.18),
      size.height * 0.08,
      splatterPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.86),
      size.height * 0.06,
      splatterPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BrushStrokePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
