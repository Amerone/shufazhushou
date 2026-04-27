import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';

class HomeQuickLaunchTemplateShortcut {
  final String title;
  final String timeLabel;
  final VoidCallback onTap;

  const HomeQuickLaunchTemplateShortcut({
    required this.title,
    required this.timeLabel,
    required this.onTap,
  });
}

class HomeQuickLaunchPanel extends StatelessWidget {
  final int recentGroupCount;
  final String? recentTimeLabel;
  final VoidCallback? onOpenRecentGroup;
  final List<HomeQuickLaunchTemplateShortcut> templateShortcuts;

  const HomeQuickLaunchPanel({
    super.key,
    required this.recentGroupCount,
    required this.recentTimeLabel,
    required this.onOpenRecentGroup,
    required this.templateShortcuts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '\u5e38\u7528\u8bb0\u8bfe\u6377\u5f84',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kSealRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '\u5c11\u8d70\u4e00\u6b65',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kSealRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (onOpenRecentGroup != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimaryBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.12)),
              ),
              child: HomeRecentGroupShortcut(
                recentGroupCount: recentGroupCount,
                recentTimeLabel: recentTimeLabel,
                onPressed: onOpenRecentGroup!,
              ),
            ),
          ],
          if (templateShortcuts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '\u6309\u5e38\u7528\u65f6\u6bb5\u6253\u5f00',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final itemWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final shortcut in templateShortcuts)
                      SizedBox(
                        width: itemWidth,
                        child: OutlinedButton(
                          onPressed: shortcut.onTap,
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            minimumSize: const Size.fromHeight(64),
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_outlined,
                                    size: 18,
                                    color: kPrimaryBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      shortcut.title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  shortcut.timeLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: kPrimaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class HomeRecentGroupShortcut extends StatelessWidget {
  final int recentGroupCount;
  final String? recentTimeLabel;
  final VoidCallback onPressed;

  const HomeRecentGroupShortcut({
    super.key,
    required this.recentGroupCount,
    required this.recentTimeLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Text(
      '\u6309\u6700\u8fd1\u73ed\u7ea7\u8bb0\u8bfe',
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
    final detail = Text(
      [
        '$recentGroupCount \u4eba',
        if (recentTimeLabel != null) recentTimeLabel,
      ].join(' \u00b7 '),
      style: theme.textTheme.bodySmall?.copyWith(color: kInkSecondary),
    );
    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.history_outlined, color: kPrimaryBlue),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final info = Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 4), detail],
              ),
            ),
          ],
        );
        final action = FilledButton.tonal(
          onPressed: onPressed,
          child: const Text('\u53bb\u8bb0\u8bfe'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, const SizedBox(height: 12), action],
          );
        }

        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 12),
            action,
          ],
        );
      },
    );
  }
}
