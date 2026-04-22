import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';

class StudentPrimaryActionsCard extends StatelessWidget {
  final VoidCallback onOpenPayment;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenExport;
  final VoidCallback onEditStudent;

  const StudentPrimaryActionsCard({
    super.key,
    required this.onOpenPayment,
    required this.onOpenAttendance,
    required this.onOpenExport,
    required this.onEditStudent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快捷操作',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '优先处理缴费和出勤，导出与编辑放在次级入口。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final primaryButtonWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: primaryButtonWidth,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      onPressed: onOpenPayment,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('新增缴费'),
                    ),
                  ),
                  SizedBox(
                    width: primaryButtonWidth,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      onPressed: onOpenAttendance,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('查看出勤'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final actionWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 8) / 2;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: actionWidth,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInkSecondary,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: onOpenExport,
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('导出报告'),
                    ),
                  ),
                  SizedBox(
                    width: actionWidth,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInkSecondary,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: onEditStudent,
                      icon: const Icon(Icons.edit_note_outlined, size: 18),
                      label: const Text('编辑档案'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
