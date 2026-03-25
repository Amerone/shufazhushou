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

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 16,
        bottom: 16,
        left: 24,
        right: 24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            Container(
              margin: const EdgeInsets.only(right: 16),
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
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kInkSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ].whereType<Widget>().toList(),
      ),
    );
  }
}
