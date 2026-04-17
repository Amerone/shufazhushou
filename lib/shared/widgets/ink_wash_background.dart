import 'package:flutter/material.dart';
import '../theme.dart';

class InkWashBackground extends StatelessWidget {
  final Widget child;
  const InkWashBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF7EE), Color(0xFFF3EEE2), Color(0xFFF8F3E8)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -80,
            left: -60,
            child: _InkBlob(
              width: 220,
              height: 180,
              start: Color(0x2A9FB7C8),
              end: Color(0x00B7A48D),
            ),
          ),
          const Positioned(
            right: -90,
            top: 120,
            child: _InkBlob(
              width: 240,
              height: 220,
              start: Color(0x1FC24E40),
              end: Color(0x00B44A3E),
            ),
          ),
          Positioned(
            left: 30,
            bottom: -110,
            child: _InkBlob(
              width: 320,
              height: 220,
              start: kPrimaryBlue.withValues(alpha: 0.08),
              end: Colors.transparent,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _InkBlob extends StatelessWidget {
  final double width;
  final double height;
  final Color start;
  final Color end;
  const _InkBlob({
    required this.width,
    required this.height,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width),
          gradient: RadialGradient(colors: [start, end]),
        ),
      ),
    );
  }
}
