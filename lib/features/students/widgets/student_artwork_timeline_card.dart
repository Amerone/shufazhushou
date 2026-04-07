import 'package:flutter/material.dart';

import '../../../core/models/student_artwork_timeline_entry.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';

class StudentArtworkTimelineCard extends StatefulWidget {
  static const _maxVisibleEntries = 6;

  final List<StudentArtworkTimelineEntry> entries;
  final VoidCallback? onOpenAttendance;

  const StudentArtworkTimelineCard({
    super.key,
    required this.entries,
    this.onOpenAttendance,
  });

  @override
  State<StudentArtworkTimelineCard> createState() =>
      _StudentArtworkTimelineCardState();
}

class _StudentArtworkTimelineCardState
    extends State<StudentArtworkTimelineCard> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant StudentArtworkTimelineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.length <=
            StudentArtworkTimelineCard._maxVisibleEntries &&
        _expanded) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canExpand =
        widget.entries.length > StudentArtworkTimelineCard._maxVisibleEntries;
    final visibleEntries =
        (_expanded
                ? widget.entries
                : widget.entries.take(
                    StudentArtworkTimelineCard._maxVisibleEntries,
                  ))
            .toList(growable: false);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('作品成长时间线', style: theme.textTheme.titleMedium),
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
                  widget.entries.isEmpty
                      ? '等待作品记录'
                      : '${widget.entries.length} 次作品记录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '把每次课堂作品分析按时间串起来，老师能快速回看孩子的稳定点、波动点和下一步练习重点。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          if (widget.entries.isEmpty)
            Column(
              children: [
                const EmptyState(
                  message: '在出勤记录中点击“作品分析”，选择课堂作品图片并完成分析后，这里会自动生成成长时间线。',
                ),
                if (widget.onOpenAttendance != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenAttendance,
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('去看出勤记录'),
                  ),
                ],
              ],
            )
          else ...[
            for (var i = 0; i < visibleEntries.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == visibleEntries.length - 1 ? 0 : 14,
                ),
                child: _TimelineItem(
                  entry: visibleEntries[i],
                  showTail: i != visibleEntries.length - 1,
                  emphasize: i == 0,
                ),
              ),
            if (canExpand) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _expanded
                          ? '已展开全部 ${widget.entries.length} 次作品记录。'
                          : '已展示最近 ${StudentArtworkTimelineCard._maxVisibleEntries} 次作品记录。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kInkSecondary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _expanded = !_expanded);
                    },
                    icon: Icon(
                      _expanded
                          ? Icons.unfold_less_outlined
                          : Icons.unfold_more_outlined,
                      size: 18,
                    ),
                    label: Text(_expanded ? '收起' : '展开更多'),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final StudentArtworkTimelineEntry entry;
  final bool showTail;
  final bool emphasize;

  const _TimelineItem({
    required this.entry,
    required this.showTail,
    required this.emphasize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = emphasize ? kSealRed : kPrimaryBlue;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (showTail)
                  Positioned(
                    top: 12,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: kInkSecondary.withValues(alpha: 0.18),
                    ),
                  ),
                Positioned(
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.18),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: emphasize ? 0.72 : 0.58),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accentColor.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.lessonLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _TimelineBadge(
                        label: entry.progressLabel,
                        color: accentColor,
                      ),
                    ],
                  ),
                  if (entry.summary.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      entry.summary.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                  ],
                  if (entry.scoreSummary.trim().isNotEmpty ||
                      entry.focusTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (entry.scoreSummary.trim().isNotEmpty)
                          _TimelineBadge(
                            label: entry.scoreSummary,
                            color: kGreen,
                          ),
                        for (final tag in entry.focusTags.take(3))
                          _TimelineBadge(label: tag, color: kPrimaryBlue),
                      ],
                    ),
                  ],
                  for (final detail in [
                    ('笔画', entry.strokeObservation),
                    ('结构', entry.structureObservation),
                    ('章法', entry.layoutObservation),
                  ])
                    if (detail.$2.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _DetailLine(label: detail.$1, content: detail.$2),
                    ],
                  if (entry.practiceSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kSealRed.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '下次前可继续练',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kSealRed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (
                            var i = 0;
                            i < entry.practiceSuggestions.length && i < 2;
                            i++
                          )
                            Padding(
                              padding: EdgeInsets.only(bottom: i == 1 ? 0 : 6),
                              child: Text(
                                '${i + 1}. ${entry.practiceSuggestions[i]}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.45,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String content;

  const _DetailLine({required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: kInkSecondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              children: [
                TextSpan(
                  text: '$label：',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kInkSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: content.trim()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TimelineBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
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
