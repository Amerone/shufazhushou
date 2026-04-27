import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';

class HomeFocusCard extends StatelessWidget {
  final String monthLabel;
  final String dateLabel;
  final int dayCount;
  final int monthCount;
  final int taskCount;
  final int studentCount;
  final bool isToday;
  final bool hasStudents;
  final bool isLoading;
  final bool hasLoadError;
  final VoidCallback onQuickEntry;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenTodayAttendance;
  final VoidCallback onOpenPaymentEntry;
  final VoidCallback onCreateStudent;
  final VoidCallback onImportStudents;
  final VoidCallback onRetryStudents;

  const HomeFocusCard({
    super.key,
    required this.monthLabel,
    required this.dateLabel,
    required this.dayCount,
    required this.monthCount,
    required this.taskCount,
    required this.studentCount,
    required this.isToday,
    required this.hasStudents,
    required this.isLoading,
    required this.hasLoadError,
    required this.onQuickEntry,
    required this.onOpenStudents,
    required this.onOpenTodayAttendance,
    required this.onOpenPaymentEntry,
    required this.onCreateStudent,
    required this.onImportStudents,
    required this.onRetryStudents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading || hasLoadError) {
      return GlassCard(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (hasLoadError ? kRed : kPrimaryBlue).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: hasLoadError
                  ? const Icon(Icons.error_outline_rounded, color: kRed)
                  : const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLoadError
                        ? '\u5b66\u751f\u6863\u6848\u52a0\u8f7d\u5931\u8d25'
                        : '\u6b63\u5728\u6574\u7406\u4eca\u65e5\u5de5\u4f5c\u53f0',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasLoadError
                        ? '\u672c\u5730\u6570\u636e\u6682\u65f6\u65e0\u6cd5\u8bfb\u53d6\uff0c\u91cd\u8bd5\u540e\u518d\u7ee7\u7eed\u8bb0\u8bfe\u6216\u67e5\u770b\u51fa\u52e4\u3002'
                        : '\u7a0d\u540e\u4f1a\u663e\u793a\u4eca\u65e5\u8bb0\u8bfe\u3001\u5f85\u529e\u548c\u8bfe\u5386\u5165\u53e3\u3002',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                  if (hasLoadError) ...[
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 520;
                        final primaryWidth = compact
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2;
                        final secondaryWidth = compact
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 24) / 3;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: primaryWidth,
                              child: FilledButton.icon(
                                onPressed: onCreateStudent,
                                style: FilledButton.styleFrom(
                                  backgroundColor: kSealRed,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('\u65b0\u589e\u5b66\u751f'),
                              ),
                            ),
                            SizedBox(
                              width: secondaryWidth,
                              child: FilledButton.tonalIcon(
                                onPressed: onRetryStudents,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('\u91cd\u8bd5'),
                              ),
                            ),
                            SizedBox(
                              width: secondaryWidth,
                              child: OutlinedButton.icon(
                                onPressed: onOpenStudents,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.people_alt_outlined,
                                  size: 18,
                                ),
                                label: const Text('\u5b66\u751f\u6863\u6848'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final pendingCount = taskCount;
    final statusText = !hasStudents
        ? '\u5148\u5efa\u7acb\u5b66\u751f\u6863\u6848'
        : pendingCount > 0
        ? '\u5f85\u5904\u7406 $pendingCount \u9879'
        : '\u4eca\u65e5\u5df2\u8bb0 $dayCount \u8282\u8bfe';

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: kInkSecondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  monthLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
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
                  hasStudents
                      ? (isToday
                            ? '\u4eca\u65e5\u4f18\u5148'
                            : '\u5f53\u524d\u65e5\u671f')
                      : '\u9996\u6b21\u5efa\u6863',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kSealRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasStudents
                ? dateLabel
                : '\u5148\u5efa\u7acb\u5b66\u751f\u6863\u6848',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HomeStatusPill(
                label: '\u4eca\u65e5\u51fa\u52e4 $dayCount',
                color: kSealRed,
              ),
              HomeStatusPill(
                label: '\u672c\u6708\u8bfe\u6b21 $monthCount',
                color: kPrimaryBlue,
              ),
              HomeStatusPill(
                label: hasStudents
                    ? '\u5b66\u751f\u603b\u6570 $studentCount'
                    : statusText,
                color: kOrange,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final primaryWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              final secondaryWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;

              if (!hasStudents) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: primaryWidth,
                      child: FilledButton.icon(
                        onPressed: onCreateStudent,
                        style: FilledButton.styleFrom(
                          backgroundColor: kSealRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('\u65b0\u589e\u5b66\u751f'),
                      ),
                    ),
                    SizedBox(
                      width: primaryWidth,
                      child: OutlinedButton.icon(
                        onPressed: onImportStudents,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('\u6279\u91cf\u5bfc\u5165'),
                      ),
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact ? constraints.maxWidth : primaryWidth,
                    child: FilledButton.icon(
                      onPressed: onQuickEntry,
                      style: FilledButton.styleFrom(
                        backgroundColor: kSealRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.brush_outlined),
                      label: const Text('\u7acb\u5373\u8bb0\u8bfe'),
                    ),
                  ),
                  SizedBox(
                    width: secondaryWidth,
                    child: FilledButton.tonalIcon(
                      onPressed: onOpenTodayAttendance,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(
                        isToday
                            ? '\u67e5\u770b\u4eca\u65e5\u51fa\u52e4'
                            : '\u67e5\u770b\u5f53\u5929\u51fa\u52e4',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: secondaryWidth,
                    child: OutlinedButton.icon(
                      onPressed: onCreateStudent,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('\u65b0\u589e\u5b66\u751f'),
                    ),
                  ),
                ],
              );
            },
          ),
          if (hasStudents) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenPaymentEntry,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('\u8bb0\u5f55\u7f34\u8d39'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenStudents,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.people_alt_outlined, size: 18),
                  label: const Text('\u5b66\u751f\u6863\u6848'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class HomeStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const HomeStatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
