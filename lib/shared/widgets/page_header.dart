import 'package:flutter/material.dart';
import 'brush_stroke_divider.dart';
import '../theme.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: kInkSecondary.withValues(alpha: 0.9),
      height: 1.45,
    );

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 18,
        bottom: 22,
        left: 24,
        right: 24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            Container(
              margin: const EdgeInsets.only(right: 16, top: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kInkSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: kPrimaryBlue,
                onPressed: onBack,
                splashColor: kPrimaryBlue.withValues(alpha: 0.08),
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const BrushStrokeDivider(
                  width: 116,
                  height: 12,
                  color: kPrimaryBlue,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: kInkSecondary.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      subtitle!,
                      style: subtitleStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: trailing,
            ),
        ].whereType<Widget>().toList(),
      ),
    );
  }
}
