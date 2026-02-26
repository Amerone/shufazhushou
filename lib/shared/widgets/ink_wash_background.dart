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
          colors: [Color(0xFFF9F5EC), Color(0xFFF3EEE3), Color(0xFFF7F2E9)],
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
              start: Color(0x26B7A48D),
              end: Color(0x00B7A48D),
            ),
          ),
          const Positioned(
            right: -90,
            top: 120,
            child: _InkBlob(
              width: 240,
              height: 220,
              start: Color(0x18B44A3E),
              end: Color(0x00B44A3E),
            ),
          ),
          Positioned(
            left: 60,
            bottom: -100,
            child: _InkBlob(
              width: 280,
              height: 200,
              start: kPrimaryBlue.withValues(alpha: 0.07),
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
