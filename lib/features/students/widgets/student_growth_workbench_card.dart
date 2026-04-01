import 'package:flutter/material.dart';

import '../../../core/services/student_growth_summary_service.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/brush_stroke_divider.dart';
import '../../../shared/widgets/glass_card.dart';

class StudentGrowthWorkbenchCard extends StatelessWidget {
  final StudentGrowthSummary summary;
  final double balance;
  final double pricePerClass;
  final VoidCallback onOpenReport;

  const StudentGrowthWorkbenchCard({
    super.key,
    required this.summary,
    required this.balance,
    required this.pricePerClass,
    required this.onOpenReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remainingLessons = pricePerClass > 0 ? balance / pricePerClass : null;
    final showRenewalAlert =
        balance < 0 ||
        (remainingLessons != null &&
            remainingLessons >= 0 &&
            remainingLessons < kBalanceAlertLessonThreshold);
    final renewalColor = balance < 0 ? kRed : kSealRed;
    final renewalLabel = remainingLessons == null
        ? '余额待跟进'
        : balance < 0
        ? '已欠费 ${balance.abs().toStringAsFixed(2)} 元'
        : '约剩 ${remainingLessons.toStringAsFixed(1)} 节课';

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
              Text(
                '成长与沟通摘要',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                  '数据截至 ${summary.dataFreshness}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const BrushStrokeDivider(width: 138, height: 12, color: kPrimaryBlue),
          const SizedBox(height: 10),
          Text(
            '把课堂反馈、练习建议和续费窗口放在一处，方便直接整理给家长。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final itemWidth = width < 420
                  ? width
                  : width < 760
                  ? (width - 12) / 2
                  : (width - 24) / 3;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricCard(
                      label: '最近课堂',
                      value: summary.latestLessonLabel,
                      color: kPrimaryBlue,
                      icon: Icons.event_available_outlined,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricCard(
                      label: '下次课',
                      value: summary.nextLessonLabel,
                      color: kSealRed,
                      icon: Icons.schedule_outlined,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricCard(
                      label: '评分摘要',
                      value: summary.latestProgressSummary,
                      color: kGreen,
                      icon: Icons.auto_graph_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
          if (summary.focusTags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summary.focusTags
                  .map(
                    (tag) => _FocusChip(
                      icon: Icons.auto_awesome_outlined,
                      label: tag,
                      color: kSealRed,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 14),
          _NarrativeBlock(
            title: '进步点',
            content: summary.progressPoint,
            color: kGreen,
            icon: Icons.trending_up_outlined,
          ),
          const SizedBox(height: 10),
          _NarrativeBlock(
            title: '待巩固点',
            content: summary.attentionPoint,
            color: kSealRed,
            icon: Icons.track_changes_outlined,
          ),
          const SizedBox(height: 10),
          _NarrativeBlock(
            title: '课后建议',
            content: summary.practiceSummary,
            color: kPrimaryBlue,
            icon: Icons.edit_note_outlined,
          ),
          if (showRenewalAlert) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: renewalColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: renewalColor.withValues(alpha: 0.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.payments_outlined, color: renewalColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '续费窗口已接近：$renewalLabel。建议同步发送成长摘要和后续课程安排。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: renewalColor,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onOpenReport,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('生成家长版月报'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryMetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NarrativeBlock extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final IconData icon;

  const _NarrativeBlock({
    required this.title,
    required this.content,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
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
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FocusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
