import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/export_template.dart';
import '../../../core/providers/home_workbench_provider.dart';
import '../../../core/services/home_workbench_service.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../students/widgets/student_action_launcher.dart';

class HomeWorkbenchPanel extends ConsumerWidget {
  const HomeWorkbenchPanel({super.key});

  Future<void> _handleTaskTap(
    BuildContext context,
    HomeWorkbenchTask task,
  ) async {
    final studentId = task.studentId;
    switch (task.type) {
      case HomeWorkbenchTaskType.debt:
      case HomeWorkbenchTaskType.renewal:
        if (studentId == null) {
          context.push('/statistics');
          return;
        }
        await showStudentPaymentSheet(
          context,
          studentId: studentId,
          studentName: task.studentName,
        );
        return;
      case HomeWorkbenchTaskType.progress:
      case HomeWorkbenchTaskType.reportReady:
        if (studentId == null) {
          context.push('/statistics');
          return;
        }
        await showStudentExportSheet(
          context,
          studentId: studentId,
          initialTemplate: ExportTemplateId.parentMonthly,
        );
        return;
      case HomeWorkbenchTaskType.churn:
      case HomeWorkbenchTaskType.trial:
        if (studentId != null) {
          context.push('/students/$studentId');
          return;
        }
        context.push('/statistics');
    }
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '优先待办',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '只保留最需要立刻处理的事项，避免首页信息堆叠。',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ],
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
              if (tasks.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.54),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: kInkSecondary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    '当前没有需要优先处理的事项，可以继续记录课程或整理学员月报。',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                );
              }

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
                      onTap: () => _handleTaskTap(context, visibleTasks[index]),
                    ),
                    if (index != visibleTasks.length - 1)
                      const SizedBox(height: 10),
                  ],
                  if (hiddenCount > 0) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => context.push('/statistics'),
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

  const _WorkbenchTaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _TaskVisualConfig.fromType(task.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.color.withValues(alpha: 0.14)),
      ),
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
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onTap,
                  icon: Icon(config.actionIcon, size: 18),
                  label: Text(task.actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
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
