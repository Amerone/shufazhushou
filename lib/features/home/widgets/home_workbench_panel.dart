import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/dismissed_insight.dart';
import '../../../core/models/export_template.dart';
import '../../../core/providers/home_workbench_provider.dart';
import '../../../core/providers/insight_provider.dart';
import '../../../core/services/dismissed_insight_policy.dart';
import '../../../core/services/home_workbench_service.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../students/widgets/student_action_launcher.dart';

class HomeWorkbenchPanel extends ConsumerWidget {
  const HomeWorkbenchPanel({super.key});

  Future<void> _handleTaskTap(
    BuildContext context,
    WidgetRef ref,
    HomeWorkbenchTask task,
  ) async {
    await InteractionFeedback.selection(context);
    if (!context.mounted) return;

    final studentId = task.studentId;
    switch (task.type) {
      case HomeWorkbenchTaskType.debt:
      case HomeWorkbenchTaskType.renewal:
        if (studentId == null) {
          await context.push('/statistics');
        } else {
          await showStudentPaymentSheet(
            context,
            studentId: studentId,
            studentName: task.studentName,
          );
        }
        ref.invalidate(homeWorkbenchProvider);
        ref.invalidate(insightProvider);
        return;
      case HomeWorkbenchTaskType.progress:
      case HomeWorkbenchTaskType.reportReady:
        if (studentId == null) {
          await context.push('/statistics');
        } else {
          await showStudentExportSheet(
            context,
            studentId: studentId,
            initialTemplate: ExportTemplateId.parentMonthly,
          );
        }
        ref.invalidate(homeWorkbenchProvider);
        ref.invalidate(insightProvider);
        return;
      case HomeWorkbenchTaskType.churn:
      case HomeWorkbenchTaskType.trial:
        if (studentId != null) {
          await context.push('/students/$studentId');
        } else {
          await context.push('/statistics');
        }
        ref.invalidate(homeWorkbenchProvider);
        return;
    }
  }

  Future<void> _dismissTask(
    BuildContext context,
    WidgetRef ref,
    HomeWorkbenchTask task,
  ) async {
    final dismissType = homeWorkbenchDismissTypeForTask(task.type);
    final snoozeDays = DismissedInsightPolicy.retentionForType(
      dismissType,
    ).inDays;

    await InteractionFeedback.selection(context);
    await ref
        .read(dismissedInsightDaoProvider)
        .insert(
          DismissedInsight(
            id: const Uuid().v4(),
            insightType: dismissType,
            studentId: task.studentId,
            dismissedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    ref.invalidate(homeWorkbenchProvider);
    ref.invalidate(insightProvider);

    if (!context.mounted) return;
    AppToast.showSuccess(context, '${task.title} 已稍后 $snoozeDays 天');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(homeWorkbenchProvider);
    const maxVisibleTasks = 3;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '优先待办',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              tasksAsync.when(
                loading: () => const _CountBadge(label: '加载中'),
                error: (_, _) => const _CountBadge(label: '待刷新'),
                data: (tasks) => _CountBadge(label: '${tasks.length} 项'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          tasksAsync.when(
            loading: () => const SizedBox(
              height: 84,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '待办摘要加载失败：$error',
                style: theme.textTheme.bodySmall?.copyWith(color: kRed),
              ),
            ),
            data: (tasks) {
              final visibleTasks = tasks
                  .take(maxVisibleTasks)
                  .toList(growable: false);
              final hiddenCount = tasks.length - visibleTasks.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < visibleTasks.length; index++) ...[
                    _WorkbenchTaskCard(
                      task: visibleTasks[index],
                      onTap: () =>
                          _handleTaskTap(context, ref, visibleTasks[index]),
                      onDismissTap: () =>
                          _dismissTask(context, ref, visibleTasks[index]),
                    ),
                    if (index != visibleTasks.length - 1)
                      const SizedBox(height: 10),
                  ],
                  if (hiddenCount > 0) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await InteractionFeedback.pageTurn(context);
                        if (!context.mounted) return;
                        await context.push('/statistics');
                      },
                      icon: const Icon(Icons.arrow_forward_outlined, size: 18),
                      label: Text('还有 $hiddenCount 项待办，去统计页查看'),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;

  const _CountBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSealRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kSealRed.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: kSealRed,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WorkbenchTaskCard extends StatelessWidget {
  final HomeWorkbenchTask task;
  final VoidCallback onTap;
  final VoidCallback onDismissTap;

  const _WorkbenchTaskCard({
    required this.task,
    required this.onTap,
    required this.onDismissTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _TaskVisualConfig.fromType(task.type);
    final dismissLabel =
        '稍后 ${DismissedInsightPolicy.retentionForType(homeWorkbenchDismissTypeForTask(task.type)).inDays} 天';

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: config.color.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Semantics(
              button: true,
              label: '${task.title}，${task.summary}，${task.actionLabel}',
              child: InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: config.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(config.icon, color: config.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              task.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _TaskActions(
                actionIcon: config.actionIcon,
                actionLabel: task.actionLabel,
                actionColor: config.color,
                dismissLabel: dismissLabel,
                onDismissTap: onDismissTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskActions extends StatelessWidget {
  final IconData actionIcon;
  final String actionLabel;
  final Color actionColor;
  final String dismissLabel;
  final VoidCallback onDismissTap;

  const _TaskActions({
    required this.actionIcon,
    required this.actionLabel,
    required this.actionColor,
    required this.dismissLabel,
    required this.onDismissTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 260;
        final actionCue = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(actionIcon, size: 18, color: actionColor),
            const SizedBox(width: 6),
            Text(
              actionLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: actionColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
        final dismissButton = TextButton.icon(
          onPressed: onDismissTap,
          style: TextButton.styleFrom(
            foregroundColor: kInkSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          ),
          icon: const Icon(Icons.visibility_off_outlined, size: 18),
          label: Text(dismissLabel),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [actionCue, const SizedBox(height: 8), dismissButton],
          );
        }

        return Row(
          children: [
            Expanded(child: actionCue),
            dismissButton,
          ],
        );
      },
    );
  }
}

class _TaskVisualConfig {
  final Color color;
  final IconData icon;
  final IconData actionIcon;

  const _TaskVisualConfig({
    required this.color,
    required this.icon,
    required this.actionIcon,
  });

  factory _TaskVisualConfig.fromType(HomeWorkbenchTaskType type) {
    switch (type) {
      case HomeWorkbenchTaskType.debt:
        return const _TaskVisualConfig(
          color: kRed,
          icon: Icons.payments_outlined,
          actionIcon: Icons.add_card_outlined,
        );
      case HomeWorkbenchTaskType.renewal:
        return const _TaskVisualConfig(
          color: kSealRed,
          icon: Icons.event_repeat_outlined,
          actionIcon: Icons.add_card_outlined,
        );
      case HomeWorkbenchTaskType.churn:
        return const _TaskVisualConfig(
          color: kOrange,
          icon: Icons.call_outlined,
          actionIcon: Icons.phone_outlined,
        );
      case HomeWorkbenchTaskType.trial:
        return const _TaskVisualConfig(
          color: kPrimaryBlue,
          icon: Icons.school_outlined,
          actionIcon: Icons.arrow_outward_outlined,
        );
      case HomeWorkbenchTaskType.progress:
        return const _TaskVisualConfig(
          color: kGreen,
          icon: Icons.trending_up_outlined,
          actionIcon: Icons.description_outlined,
        );
      case HomeWorkbenchTaskType.reportReady:
        return const _TaskVisualConfig(
          color: kPrimaryBlue,
          icon: Icons.description_outlined,
          actionIcon: Icons.ios_share_outlined,
        );
    }
  }
}
