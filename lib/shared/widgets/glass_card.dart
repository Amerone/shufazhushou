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
    final radius = BorderRadius.circular(18);
    final decoration = BoxDecoration(
      color: Colors.white.withValues(alpha: 0.84),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.78),
        ],
      ),
      borderRadius: radius,
      border: Border.all(color: Colors.white.withValues(alpha: 0.88), width: 1),
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
    );

    Widget buildSurface({required bool useInk}) {
      if (!useInk) {
        return Container(
          width: width,
          height: height,
          padding: padding,
          decoration: decoration,
          child: child,
        );
      }

      final content = padding == null
          ? child
          : Padding(padding: padding!, child: child);
      return Ink(
        width: width,
        height: height,
        decoration: decoration,
        child: content,
      );
    }

    Widget buildCard({required bool useInk}) {
      final surface = buildSurface(useInk: useInk);
      return ClipRRect(
        borderRadius: radius,
        child: enableBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: surface,
              )
            : surface,
      );
    }

    final card = buildCard(useInk: false);

    Widget result = card;
    if (onTap != null) {
      result = Semantics(
        button: true,
        label: semanticLabel,
        onTap: onTap,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: radius,
            mouseCursor: SystemMouseCursors.click,
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
            child: buildCard(useInk: true),
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
