import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool enableBlur;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.semanticLabel,
    this.enableBlur = false,
    this.blurSigma = 8,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.88),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B7D6B).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: kPrimaryBlue.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: enableBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: surface,
            )
          : surface,
    );

    Widget result = card;
    if (onTap != null) {
      result = Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return kPrimaryBlue.withValues(alpha: 0.06);
              }
              if (states.contains(WidgetState.hovered)) {
                return kPrimaryBlue.withValues(alpha: 0.02);
              }
              return null;
            }),
            onTap: onTap,
            child: card,
          ),
        ),
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: result);
    }

    return result;
  }
}
