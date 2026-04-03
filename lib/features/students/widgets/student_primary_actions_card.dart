import 'package:flutter/material.dart';

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
          Text('常用操作', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('把最常用的缴费和出勤放前面，常看但不高频的功能放后面。', style: theme.textTheme.bodySmall),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final primaryButtonWidth = width < 420 ? width : (width - 10) / 2;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: primaryButtonWidth,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onOpenExport,
                icon: const Icon(Icons.description_outlined),
                label: const Text('导出报告'),
              ),
              TextButton.icon(
                onPressed: onEditStudent,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('编辑档案'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
