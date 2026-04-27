import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';

class HomeInitialSetupBanner extends StatelessWidget {
  final int readyCount;
  final VoidCallback onOpenSetup;

  const HomeInitialSetupBanner({
    super.key,
    required this.readyCount,
    required this.onOpenSetup,
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
                '\u9996\u6b21\u4f7f\u7528\u5efa\u8bae\u5148\u5b8c\u6210\u5f15\u5bfc',
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
                  color: kPrimaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$readyCount/2 \u5df2\u5b8c\u6210',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onOpenSetup,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('\u67e5\u770b\u5f00\u8bfe\u5f15\u5bfc'),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSectionTitleRow extends StatelessWidget {
  final String title;
  final String countText;
  final Color color;

  const HomeSectionTitleRow({
    super.key,
    required this.title,
    required this.countText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        countText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleText = Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleText, const SizedBox(height: 8), countBadge],
          );
        }

        return Row(
          children: [
            Expanded(child: titleText),
            const SizedBox(width: 12),
            countBadge,
          ],
        );
      },
    );
  }
}

class HomeTodayAction extends StatelessWidget {
  final VoidCallback onPressed;

  const HomeTodayAction({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryBlue,
        backgroundColor: Colors.white.withValues(alpha: 0.58),
        overlayColor: kSealRed.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: kInkSecondary.withValues(alpha: 0.18)),
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.today_outlined, size: 18),
      label: const Text('\u56de\u5230\u4eca\u5929'),
    );
  }
}

class HomeQuickEntryAction extends StatelessWidget {
  final VoidCallback onPressed;

  const HomeQuickEntryAction({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kSealRed.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'home-quick-entry',
        onPressed: onPressed,
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: kSealRed,
        foregroundColor: Colors.white,
        splashColor: Colors.white.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        icon: const Icon(Icons.brush_outlined),
        label: const Text(
          '\u7acb\u5373\u8bb0\u8bfe',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class HomeSetupAction extends StatelessWidget {
  final VoidCallback onPressed;

  const HomeSetupAction({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'home-setup-entry',
      onPressed: onPressed,
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: kPrimaryBlue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text(
        '\u65b0\u589e\u5b66\u751f',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
