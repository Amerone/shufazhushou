import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/attendance_edit_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/models/student.dart';

class AttendanceList extends ConsumerWidget {
  const AttendanceList({super.key});

  String _durationLabel(String start, String end) {
    final startTime = parseTime(start);
    final endTime = parseTime(end);
    final minutes = (endTime.hour * 60 + endTime.minute) - (startTime.hour * 60 + startTime.minute);

    if (minutes <= 0) return '时长待确认';
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分钟';
  }

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
            final status = statusLabel(r.status);
            final sColor = statusColor(r.status);
            final durationLabel = _durationLabel(r.startTime, r.endTime);

            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sColor.withValues(alpha: 0.16)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AttendanceEditSheet(record: r),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 420;
                      final deleteAction = _RecordActionButton(
                        onPressed: () async {
                          final confirm = await AppToast.showConfirm(context, '确认删除此出勤记录？');
                          if (!confirm) return;
                          await ref.read(attendanceDaoProvider).delete(r.id);
                          invalidateAfterAttendanceChange(ref);
                        },
                      );

                      final actionHint = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          '点击编辑',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kPrimaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_outlined, color: sColor, size: 18),
                                const SizedBox(height: 4),
                                Text(
                                  '${i + 1}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: sColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nameMap[r.studentId] ?? r.studentId,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '第 ${i + 1} 条记录',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusBadge(status: status, color: sColor),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _MetaChip(
                                      icon: Icons.access_time_outlined,
                                      label: '${r.startTime} - ${r.endTime}',
                                    ),
                                    _MetaChip(
                                      icon: Icons.timelapse_outlined,
                                      label: durationLabel,
                                    ),
                                    _MetaChip(
                                      icon: Icons.payments_outlined,
                                      label: '¥${r.feeAmount.toStringAsFixed(0)}',
                                    ),
                                  ],
                                ),
                                if (r.note?.trim().isNotEmpty == true) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    r.note!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: kInkSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                if (compact)
                                  Row(
                                    children: [
                                      actionHint,
                                      const Spacer(),
                                      deleteAction,
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                actionHint,
                                const SizedBox(height: 10),
                                deleteAction,
                              ],
                            ),
                          ],
                        ],
                      );
                    },
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

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kInkSecondary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RecordActionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RecordActionButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        tooltip: '删除记录',
        onPressed: onPressed,
        icon: const Icon(Icons.delete_outline),
        color: kRed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
