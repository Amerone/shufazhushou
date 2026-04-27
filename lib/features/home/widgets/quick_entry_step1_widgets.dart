import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/structured_attendance_feedback.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import 'quick_entry_common_widgets.dart';

class QuickEntryRememberedDefaultsBanner extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String statusLabel;

  const QuickEntryRememberedDefaultsBanner({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.history_toggle_off_outlined,
              size: 16,
              color: kPrimaryBlue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已沿用上次常用设置：$startTime-$endTime，状态“$statusLabel”。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: kPrimaryBlue,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuickEntrySelectedStudentsSection extends StatelessWidget {
  final List<String> selectedNames;

  const QuickEntrySelectedStudentsSection({
    super.key,
    required this.selectedNames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已选学员', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in selectedNames.take(12))
                Chip(
                  label: Text(name),
                  backgroundColor: kPrimaryBlue.withValues(alpha: 0.08),
                  side: BorderSide(color: kPrimaryBlue.withValues(alpha: 0.12)),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (selectedNames.length > 12)
                Chip(
                  label: Text('另 ${selectedNames.length - 12} 人'),
                  backgroundColor: kSealRed.withValues(alpha: 0.08),
                  side: BorderSide(color: kSealRed.withValues(alpha: 0.12)),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: kSealRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class QuickEntrySelectionSummaryPanel extends StatelessWidget {
  final String dateLabel;
  final String timeRangeLabel;
  final String statusLabel;
  final Color statusColor;
  final int selectedCount;
  final String estimatedFeeLabel;

  const QuickEntrySelectionSummaryPanel({
    super.key,
    required this.dateLabel,
    required this.timeRangeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.selectedCount,
    required this.estimatedFeeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.12)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          QuickInfoPill(icon: Icons.calendar_today_outlined, label: dateLabel),
          QuickInfoPill(
            icon: Icons.access_time_outlined,
            label: timeRangeLabel,
          ),
          QuickInfoPill(
            icon: Icons.flag_outlined,
            label: statusLabel,
            color: statusColor,
          ),
          QuickInfoPill(
            icon: Icons.groups_2_outlined,
            label: '$selectedCount 人',
          ),
          QuickInfoPill(
            icon: Icons.payments_outlined,
            label: estimatedFeeLabel,
            color: kPrimaryBlue,
          ),
        ],
      ),
    );
  }
}

class QuickEntryFeedbackSection extends StatelessWidget {
  final Set<String> selectedLessonFocusTags;
  final TextEditingController homePracticeController;
  final double? strokeQuality;
  final double? structureAccuracy;
  final double? rhythmConsistency;
  final void Function(String tag, bool selected) onLessonFocusTagSelected;
  final ValueChanged<double> onStrokeQualityChanged;
  final VoidCallback onStrokeQualityCleared;
  final ValueChanged<double> onStructureAccuracyChanged;
  final VoidCallback onStructureAccuracyCleared;
  final ValueChanged<double> onRhythmConsistencyChanged;
  final VoidCallback onRhythmConsistencyCleared;

  const QuickEntryFeedbackSection({
    super.key,
    required this.selectedLessonFocusTags,
    required this.homePracticeController,
    required this.strokeQuality,
    required this.structureAccuracy,
    required this.rhythmConsistency,
    required this.onLessonFocusTagSelected,
    required this.onStrokeQualityChanged,
    required this.onStrokeQualityCleared,
    required this.onStructureAccuracyChanged,
    required this.onStructureAccuracyCleared,
    required this.onRhythmConsistencyChanged,
    required this.onRhythmConsistencyCleared,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.only(top: 4),
        title: Text('课堂反馈（可选）', style: theme.textTheme.titleSmall),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('课堂重点', style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kLessonFocusTagOptions
                .map(
                  (tag) => FilterChip(
                    label: Text(tag),
                    selected: selectedLessonFocusTags.contains(tag),
                    onSelected: (selected) {
                      unawaited(InteractionFeedback.selection(context));
                      onLessonFocusTagSelected(tag, selected);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: homePracticeController,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '课后练习建议',
              hintText: '例如：每日临摹 15 分钟，重点观察起收笔节奏。',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.56),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('进步评分（0-5）', style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 8),
          ScoreEditor(
            label: '笔画质量',
            value: strokeQuality,
            onChanged: onStrokeQualityChanged,
            onClear: onStrokeQualityCleared,
          ),
          ScoreEditor(
            label: '结构准确',
            value: structureAccuracy,
            onChanged: onStructureAccuracyChanged,
            onClear: onStructureAccuracyCleared,
          ),
          ScoreEditor(
            label: '节奏连贯',
            value: rhythmConsistency,
            onChanged: onRhythmConsistencyChanged,
            onClear: onRhythmConsistencyCleared,
          ),
        ],
      ),
    );
  }
}

class ScoreEditor extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double> onChanged;
  final VoidCallback onClear;

  const ScoreEditor({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                value == null ? '未评分' : value!.toStringAsFixed(1),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  unawaited(InteractionFeedback.selection(context));
                  onClear();
                },
                child: const Text('清空'),
              ),
            ],
          ),
          Slider(
            value: value ?? 3.0,
            min: 0,
            max: 5,
            divisions: 10,
            label: (value ?? 3.0).toStringAsFixed(1),
            semanticFormatterCallback: (nextValue) =>
                '$label ${nextValue.toStringAsFixed(1)} 分',
            onChanged: (nextValue) {
              unawaited(InteractionFeedback.selection(context));
              onChanged(nextValue);
            },
          ),
        ],
      ),
    );
  }
}
