import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/insight_provider.dart';
import '../../../core/providers/metrics_provider.dart';
import '../../../core/providers/revenue_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/attendance_edit_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/models/student.dart';

class AttendanceList extends ConsumerWidget {
  const AttendanceList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedDateProvider);
    final asyncAll = ref.watch(attendanceProvider);
    final students = ref.watch(studentProvider).valueOrNull ?? [];
    final nameMap = buildDisplayNameMap(students.map((m) => m.student).toList());

    final dateStr = formatDate(selectedDate);

    return asyncAll.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (allRecords) {
        final records = allRecords.where((r) => r.date == dateStr).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        if (records.isEmpty) {
          return const EmptyState(message: '当日暂无出勤记录');
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final r = records[i];
            final status = kStatusLabel[r.status] ?? r.status;
            final statusColor = kStatusColor[r.status] ?? kInkSecondary;

            return Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AttendanceEditSheet(record: r),
                ),
                onLongPress: () async {
                  final confirm = await AppToast.showConfirm(context, '确认删除此出勤记录？');
                  if (!confirm) return;
                  await ref.read(attendanceDaoProvider).delete(r.id);
                  ref.invalidate(attendanceProvider);
                  ref.invalidate(feeSummaryProvider);
                  ref.invalidate(metricsProvider);
                  ref.invalidate(revenueProvider);
                  ref.invalidate(insightProvider);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 42,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameMap[r.studentId] ?? r.studentId,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r.startTime} - ${r.endTime}  ${r.note ?? ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
