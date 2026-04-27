import 'package:flutter/material.dart';

import '../../../shared/theme.dart';

enum QuickEntryConflictResolution { overwrite, changeTime, cancel }

class QuickEntryConflictItem {
  final String studentName;
  final String existingTimeRange;
  final String existingStatusLabel;

  const QuickEntryConflictItem({
    required this.studentName,
    required this.existingTimeRange,
    required this.existingStatusLabel,
  });
}

Future<QuickEntryConflictResolution> showQuickEntryConflictDialog({
  required BuildContext context,
  required String currentSlot,
  required List<QuickEntryConflictItem> conflicts,
}) async {
  final result = await showDialog<QuickEntryConflictResolution>(
    context: context,
    builder: (dialogCtx) => _QuickEntryConflictDialog(
      currentSlot: currentSlot,
      conflicts: conflicts,
    ),
  );

  return result ?? QuickEntryConflictResolution.cancel;
}

class _QuickEntryConflictDialog extends StatelessWidget {
  final String currentSlot;
  final List<QuickEntryConflictItem> conflicts;

  const _QuickEntryConflictDialog({
    required this.currentSlot,
    required this.conflicts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: screenSize.height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_busy_rounded,
                      color: kOrange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '发现时段冲突',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '本次将保存 $currentSlot。以下学员该时段已有记录，请选择处理方式。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kInkSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: conflicts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final conflict = conflicts[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kInkSecondary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: kInkSecondary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: kInkSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conflict.studentName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '已有记录：${conflict.existingTimeRange} · ${conflict.existingStatusLabel}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: kInkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '覆盖会保留旧记录中的课堂反馈、课后练习和作品照片，除非本次填写了新的内容。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kInkSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(QuickEntryConflictResolution.cancel),
                    child: const Text('取消保存'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(QuickEntryConflictResolution.changeTime),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: const Text('返回改时间'),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(QuickEntryConflictResolution.overwrite),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('覆盖并保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
