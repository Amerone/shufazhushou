import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/dismissed_insight.dart';
import '../../../core/providers/insight_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';

class InsightList extends ConsumerWidget {
  const InsightList({super.key});

  static const _typeLabel = {
    InsightType.debt: '欠费提醒',
    InsightType.churn: '流失预警',
    InsightType.peak: '高峰提示',
    InsightType.trial: '试听转化',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncInsights = ref.watch(insightProvider);

    return asyncInsights.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
      data: (insights) {
        if (insights.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
            return Card(
              child: ListTile(
                title: Text(
                  insight.studentName.isEmpty
                      ? (_typeLabel[insight.type] ?? '')
                      : '${_typeLabel[insight.type] ?? ''} · ${insight.studentName}',
                ),
                subtitle: Text(insight.message),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (insight.studentId != null)
                      TextButton(
                        onPressed: () => context.push('/students/${insight.studentId}'),
                        child: const Text('处理'),
                      ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(dismissedInsightDaoProvider).insert(
                          DismissedInsight(
                            id: const Uuid().v4(),
                            insightType: insight.type.name,
                            studentId: insight.studentId,
                            dismissedAt: DateTime.now().millisecondsSinceEpoch,
                          ),
                        );
                        ref.invalidate(insightProvider);
                      },
                      style: TextButton.styleFrom(foregroundColor: kInkSecondary),
                      child: const Text('忽略'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
