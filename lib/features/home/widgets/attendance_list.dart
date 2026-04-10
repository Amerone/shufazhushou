import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/attendance.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/attendance_edit_sheet.dart';
import '../../../shared/widgets/attendance_artwork_preview.dart';
import '../../../shared/widgets/brush_stroke_divider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/models/student.dart';
import '../../students/widgets/attendance_artwork_analysis_launcher.dart';
import '../../students/widgets/student_action_launcher.dart';
import 'quick_entry_sheet.dart';

class AttendanceList extends ConsumerStatefulWidget {
  const AttendanceList({super.key});

  @override
  ConsumerState<AttendanceList> createState() => _AttendanceListState();
}

class _AttendanceListState extends ConsumerState<AttendanceList> {
  final Set<String> _analyzingImageRecordIds = <String>{};

  String _durationLabel(String start, String end) {
    final startTime = parseTime(start);
    final endTime = parseTime(end);
    final minutes =
        (endTime.hour * 60 + endTime.minute) -
        (startTime.hour * 60 + startTime.minute);

    if (minutes <= 0) return '时长待确认';
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分钟';
  }

  Future<void> _analyzeAttendanceImage(
    Attendance record,
    String studentName,
  ) async {
    await launchAttendanceArtworkAnalysis(
      context,
      ref,
      record: record,
      studentName: studentName,
      onStarted: () {
        if (!mounted) return;
        setState(() => _analyzingImageRecordIds.add(record.id));
      },
      onFinished: () {
        if (!mounted) return;
        setState(() => _analyzingImageRecordIds.remove(record.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncRecords = ref.watch(selectedDateAttendanceProvider);
    final students = ref.watch(studentProvider).valueOrNull ?? [];
    final studentMap = {
      for (final item in students) item.student.id: item.student,
    };
    final nameMap = buildDisplayNameMap(
      students.map((m) => m.student).toList(),
    );

    return asyncRecords.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (records) {
        final sortedRecords = [...records]
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        if (sortedRecords.isEmpty) {
          if (students.isEmpty) {
            return const EmptyState(message: '当日暂无出勤记录');
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(message: '当日暂无出勤记录'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await InteractionFeedback.selection(context);
                  if (!context.mounted) return;
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const QuickEntrySheet(),
                  );
                },
                icon: const Icon(Icons.brush_outlined),
                label: const Text('立即记课'),
              ),
              const SizedBox(height: 8),
              Text('记完后，这里会直接出现当天出勤名单。', style: theme.textTheme.bodySmall),
            ],
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedRecords.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, i) {
            final r = sortedRecords[i];
            final status = statusLabel(r.status);
            final sColor = statusColor(r.status);
            final durationLabel = _durationLabel(r.startTime, r.endTime);
            final studentName = nameMap[r.studentId] ?? r.studentId;
            final analyzingImage = _analyzingImageRecordIds.contains(r.id);

            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.54),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sColor.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B7D6B).withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return sColor.withValues(alpha: 0.08);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return sColor.withValues(alpha: 0.03);
                  }
                  return null;
                }),
                onTap: () {
                  unawaited(InteractionFeedback.selection(context));
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AttendanceEditSheet(
                      record: r,
                      onAnalyzeArtwork: () =>
                          _analyzeAttendanceImage(r, studentName),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 420;
                      final deleteAction = _RecordActionButton(
                        onPressed: () async {
                          final confirm = await AppToast.showConfirm(
                            context,
                            '确认删除此出勤记录？',
                          );
                          if (!confirm) return;
                          await ref.read(attendanceDaoProvider).delete(r.id);
                          if (!context.mounted) return;
                          await InteractionFeedback.seal(context);
                          invalidateAfterAttendanceChange(ref);
                        },
                      );

                      final actionHint = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: kInkSecondary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          '轻触可改',
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
                            width: 50,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: sColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_outlined,
                                  color: sColor,
                                  size: 18,
                                ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            studentName,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          BrushStrokeDivider(
                                            width: compact ? 72 : 84,
                                            height: 10,
                                            color: sColor,
                                          ),
                                          const SizedBox(height: 6),
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
                                      label:
                                          '¥${r.feeAmount.toStringAsFixed(0)}',
                                    ),
                                  ],
                                ),
                                if (r.note?.trim().isNotEmpty == true) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kPrimaryBlue.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      r.note!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: kInkSecondary,
                                            height: 1.5,
                                          ),
                                    ),
                                  ),
                                ],
                                if (r.artworkImagePath?.trim().isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 10),
                                  AttendanceArtworkPreview(
                                    imagePath: r.artworkImagePath!,
                                    title: '本次课堂作品',
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: analyzingImage
                                          ? null
                                          : () async {
                                              await InteractionFeedback.selection(
                                                context,
                                              );
                                              if (!context.mounted) return;
                                              await _analyzeAttendanceImage(
                                                r,
                                                studentName,
                                              );
                                            },
                                      icon: analyzingImage
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.camera_alt_outlined,
                                              size: 18,
                                            ),
                                      label: Text(
                                        analyzingImage ? '分析中...' : '作品分析',
                                      ),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: () async {
                                        await InteractionFeedback.selection(
                                          context,
                                        );
                                        if (!context.mounted) return;
                                        await showStudentPaymentSheet(
                                          context,
                                          studentId: r.studentId,
                                          studentName: studentName,
                                          pricePerClass: studentMap[r.studentId]
                                              ?.pricePerClass,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.payments_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('记录缴费'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await InteractionFeedback.pageTurn(
                                          context,
                                        );
                                        if (!context.mounted) return;
                                        context.push(
                                          '/students/${r.studentId}',
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.person_outline_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('学生档案'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
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

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
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

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(14),
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
        style: IconButton.styleFrom(overlayColor: kRed.withValues(alpha: 0.12)),
      ),
    );
  }
}
