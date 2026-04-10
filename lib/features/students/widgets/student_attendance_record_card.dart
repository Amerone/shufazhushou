import 'package:flutter/material.dart';

import '../../../core/models/attendance.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/attendance_artwork_preview.dart';
import '../../../shared/widgets/glass_card.dart';

class StudentAttendanceRecordCard extends StatelessWidget {
  final Attendance record;
  final VoidCallback onTap;
  final VoidCallback onAnalyzeImage;
  final bool analyzingImage;

  const StudentAttendanceRecordCard({
    super.key,
    required this.record,
    required this.onTap,
    required this.onAnalyzeImage,
    required this.analyzingImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColorValue = statusColor(record.status);
    final progressItems = buildAttendanceProgressItems(record);
    final startTime = parseTime(record.startTime);
    final endTime = parseTime(record.endTime);
    final minutes =
        (endTime.hour * 60 + endTime.minute) -
        (startTime.hour * 60 + startTime.minute);
    final durationLabel = minutes <= 0
        ? '\u65f6\u957f\u5f85\u5b9a'
        : minutes < 60
        ? '$minutes \u5206\u949f'
        : minutes % 60 == 0
        ? '${minutes ~/ 60} \u5c0f\u65f6'
        : '${minutes ~/ 60} \u5c0f\u65f6 ${minutes % 60} \u5206\u949f';

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final analysisAction = Container(
            decoration: BoxDecoration(
              color: kPrimaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: '\u5206\u6790\u5b57\u5e16\u56fe\u7247',
              onPressed: analyzingImage ? null : onAnalyzeImage,
              icon: analyzingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              color: kPrimaryBlue,
              visualDensity: VisualDensity.compact,
            ),
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: statusColorValue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: statusColorValue,
                      size: 18,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel(record.status),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColorValue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            record.date,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (compact) analysisAction,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StudentDetailMetaChip(
                          icon: Icons.access_time_outlined,
                          label: '${record.startTime} - ${record.endTime}',
                        ),
                        StudentDetailMetaChip(
                          icon: Icons.timelapse_outlined,
                          label: durationLabel,
                        ),
                        StudentDetailMetaChip(
                          icon: Icons.payments_outlined,
                          label: '\u00a5${record.feeAmount.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                    if (record.note?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(record.note!, style: theme.textTheme.bodySmall),
                    ],
                    if (record.artworkImagePath?.trim().isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 8),
                      AttendanceArtworkPreview(
                        imagePath: record.artworkImagePath!,
                        title: '\u672c\u6b21\u8bfe\u5802\u4f5c\u54c1',
                      ),
                    ],
                    if (record.lessonFocusTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: record.lessonFocusTags
                            .map(
                              (tag) => StudentDetailMetaChip(
                                icon: Icons.auto_awesome_outlined,
                                label: tag,
                                color: kSealRed,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (record.homePracticeNote?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      _FeedbackBlock(
                        icon: Icons.edit_note_outlined,
                        title: '\u8bfe\u540e\u7ec3\u4e60',
                        content: record.homePracticeNote!,
                        color: kPrimaryBlue,
                      ),
                    ],
                    if (progressItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: progressItems
                            .map(
                              (item) => StudentDetailMetaChip(
                                icon: Icons.trending_up_outlined,
                                label: item,
                                color: kGreen,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[const SizedBox(width: 10), analysisAction],
            ],
          );
        },
      ),
    );
  }
}

class StudentDetailMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const StudentDetailMetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? kInkSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color == null
            ? Colors.white.withValues(alpha: 0.72)
            : resolvedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color == null
              ? kInkSecondary.withValues(alpha: 0.1)
              : resolvedColor.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color == null ? null : resolvedColor,
              fontWeight: color == null ? null : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _FeedbackBlock({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<String> buildAttendanceProgressItems(Attendance record) {
  final scores = record.progressScores;
  if (scores == null || scores.isEmpty) return const <String>[];

  final result = <String>[];
  if (scores.strokeQuality != null) {
    result.add(
      '\u7b14\u753b\u8d28\u91cf\uff1a${scores.strokeQuality!.toStringAsFixed(1)}',
    );
  }
  if (scores.structureAccuracy != null) {
    result.add(
      '\u7ed3\u6784\u51c6\u786e\u5ea6\uff1a${scores.structureAccuracy!.toStringAsFixed(1)}',
    );
  }
  if (scores.rhythmConsistency != null) {
    result.add(
      '\u8282\u594f\u7a33\u5b9a\u6027\uff1a${scores.rhythmConsistency!.toStringAsFixed(1)}',
    );
  }
  return result;
}
