import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/dismissed_insight.dart';
import '../../../core/models/export_template.dart';
import '../../../core/providers/home_workbench_provider.dart';
import '../../../core/providers/insight_provider.dart';
import '../../../core/services/dismissed_insight_policy.dart';
import '../../../core/services/insight_aggregation_service.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../students/widgets/student_action_launcher.dart';

class InsightList extends ConsumerWidget {
  const InsightList({super.key});

  static const _typeLabel = {
    InsightType.debt: '欠费提醒',
    InsightType.renewal: '续费窗口',
    InsightType.churn: '流失预警',
    InsightType.peak: '高峰提示',
    InsightType.trial: '试听转化',
    InsightType.progress: '进步洞察',
  };

  static const _typeIcon = {
    InsightType.debt: Icons.payments_outlined,
    InsightType.renewal: Icons.event_repeat_outlined,
    InsightType.churn: Icons.warning_amber_outlined,
    InsightType.peak: Icons.auto_graph_outlined,
    InsightType.trial: Icons.school_outlined,
    InsightType.progress: Icons.trending_up_outlined,
  };

  static const _typeColor = {
    InsightType.debt: kSealRed,
    InsightType.renewal: kOrange,
    InsightType.churn: kRed,
    InsightType.peak: kOrange,
    InsightType.trial: kPrimaryBlue,
    InsightType.progress: kGreen,
  };

  static const _typeHint = {
    InsightType.debt: '优先核对欠费并提醒续费',
    InsightType.renewal: '建议尽快确认续费时间',
    InsightType.churn: '建议尽快回访，确认学习节奏',
    InsightType.peak: '关注高峰时段，提前调整排课',
    InsightType.trial: '尽快跟进试听反馈与转化',
    InsightType.progress: '建议生成成长快照并同步家长',
  };

  Future<void> _handlePrimaryAction(
    BuildContext context,
    Insight insight,
  ) async {
    final studentId = insight.studentId;
    if (studentId == null) return;

    switch (insight.type) {
      case InsightType.debt:
      case InsightType.renewal:
        await showStudentPaymentSheet(
          context,
          studentId: studentId,
          studentName: insight.studentName,
        );
        return;
      case InsightType.progress:
        await showStudentExportSheet(
          context,
          studentId: studentId,
          initialTemplate: ExportTemplateId.parentMonthly,
        );
        return;
      case InsightType.churn:
      case InsightType.trial:
        context.push('/students/$studentId');
        return;
      case InsightType.peak:
        return;
    }
  }

  String? _primaryLabelFor(Insight insight) {
    if (insight.studentId == null) return null;

    switch (insight.type) {
      case InsightType.debt:
        return '记录缴费';
      case InsightType.renewal:
        return '登记续费';
      case InsightType.progress:
        return '生成月报';
      case InsightType.churn:
      case InsightType.trial:
        return '查看档案';
      case InsightType.peak:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncInsights = ref.watch(insightProvider);

    return asyncInsights.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
      data: (insights) {
        if (insights.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                '笔墨安然，暂无提醒',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'serif',
                  letterSpacing: 1.2,
                ),
              ),
            ),
          );
        }

        return Column(
          children: insights.map((insight) {
            final color = _typeColor[insight.type] ?? kPrimaryBlue;
            final icon =
                _typeIcon[insight.type] ?? Icons.notifications_outlined;
            final typeLabel = _typeLabel[insight.type] ?? '经营提醒';
            final title = insight.studentName.isEmpty
                ? typeLabel
                : insight.studentName;
            final snoozeDays = DismissedInsightPolicy.retentionForInsight(
              insight.type,
            ).inDays;

            return Container(
              margin: EdgeInsets.only(
                bottom: insight == insights.last ? 0 : 10,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InsightMetaChip(
                                  icon: icon,
                                  label: typeLabel,
                                  color: color,
                                ),
                                _InsightMetaChip(
                                  icon: Icons.flag_outlined,
                                  label: _typeHint[insight.type] ?? '建议尽快处理',
                                  color: kPrimaryBlue,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              insight.message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimaryBlue.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline,
                                    size: 16,
                                    color: kPrimaryBlue,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      insight.suggestion,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: kInkSecondary,
                                            height: 1.4,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '计算逻辑：${insight.calcLogic}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: kInkSecondary,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InsightMetaChip(
                                  icon: Icons.update_outlined,
                                  label: '数据截至 ${insight.dataFreshness}',
                                  color: kInkSecondary,
                                ),
                                _InsightMetaChip(
                                  icon: Icons.visibility_off_outlined,
                                  label: '$snoozeDays 天后自动恢复',
                                  color: kOrange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InsightActions(
                    primaryLabel: _primaryLabelFor(insight),
                    onPrimaryTap: insight.studentId == null
                        ? null
                        : () => _handlePrimaryAction(context, insight),
                    onDismissTap: () async {
                      await ref
                          .read(dismissedInsightDaoProvider)
                          .insert(
                            DismissedInsight(
                              id: const Uuid().v4(),
                              insightType: insight.type.name,
                              studentId: insight.studentId,
                              dismissedAt:
                                  DateTime.now().millisecondsSinceEpoch,
                            ),
                          );
                      if (context.mounted) {
                        AppToast.showSuccess(
                          context,
                          '$typeLabel已暂停 $snoozeDays 天',
                        );
                      }
                      ref.invalidate(insightProvider);
                      ref.invalidate(homeWorkbenchProvider);
                    },
                    snoozeLabel: '稍后 $snoozeDays 天提醒',
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _InsightMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InsightMetaChip({
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

class _InsightActions extends StatelessWidget {
  final String? primaryLabel;
  final VoidCallback? onPrimaryTap;
  final VoidCallback onDismissTap;
  final String snoozeLabel;

  const _InsightActions({
    required this.primaryLabel,
    required this.onPrimaryTap,
    required this.onDismissTap,
    required this.snoozeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final dismissButton = TextButton.icon(
          onPressed: onDismissTap,
          style: TextButton.styleFrom(foregroundColor: kInkSecondary),
          icon: const Icon(Icons.visibility_off_outlined, size: 18),
          label: Text(snoozeLabel),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (primaryLabel != null && onPrimaryTap != null)
                FilledButton.tonalIcon(
                  onPressed: onPrimaryTap,
                  icon: const Icon(Icons.arrow_outward_outlined, size: 18),
                  label: Text(primaryLabel!),
                ),
              if (primaryLabel != null && onPrimaryTap != null)
                const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: dismissButton),
            ],
          );
        }

        return Row(
          children: [
            if (primaryLabel != null && onPrimaryTap != null)
              FilledButton.tonalIcon(
                onPressed: onPrimaryTap,
                icon: const Icon(Icons.arrow_outward_outlined, size: 18),
                label: Text(primaryLabel!),
              ),
            const Spacer(),
            dismissButton,
          ],
        );
      },
    );
  }
}
