import 'package:flutter/material.dart';
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
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 18.0
        : 24.0;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: kInkSecondary.withValues(alpha: 0.9),
      height: 1.45,
    );

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 18,
        bottom: 18,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBack = onBack != null;
          final hasTrailing = trailing != null;
          final compact =
              hasTrailing &&
              (constraints.maxWidth < 360 ||
                  (hasBack && constraints.maxWidth < 380) ||
                  (textScale > 1.2 && constraints.maxWidth < 480));
          final maxInlineTrailingWidth =
              (constraints.maxWidth * (hasBack ? 0.34 : 0.42))
                  .clamp(72.0, 180.0)
                  .toDouble();
          final titleBlock = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
                ],
              ],
            ),
          );
          Widget trailingSlot({required bool belowTitle}) {
            return Align(
              alignment: belowTitle
                  ? Alignment.centerRight
                  : Alignment.topRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: belowTitle
                      ? constraints.maxWidth
                      : maxInlineTrailingWidth,
                ),
                child: trailing!,
              ),
            );
          }

          final headerRow = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onBack != null) ...[
                Container(
                  margin: EdgeInsets.only(right: compact ? 12 : 16, top: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kInkSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: IconButton(
                    tooltip: '返回',
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: kPrimaryBlue,
                    onPressed: onBack,
                    splashColor: kPrimaryBlue.withValues(alpha: 0.08),
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
              ],
              titleBlock,
              if (hasTrailing && !compact)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: trailingSlot(belowTitle: false),
                ),
            ],
          );

          if (!compact) return headerRow;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerRow,
              const SizedBox(height: 12),
              trailingSlot(belowTitle: true),
            ],
          );
        },
      ),
    );
  }
}
