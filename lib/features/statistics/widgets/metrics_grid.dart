import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/metrics_provider.dart';
import '../../../core/providers/statistics_period_provider.dart';
import '../../../shared/theme.dart';

class MetricsGrid extends ConsumerWidget {
  const MetricsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMetrics = ref.watch(metricsProvider);
    final period = ref.watch(statisticsPeriodProvider);

    return Column(
      children: [
        SegmentedButton<StatisticsPeriod>(
          segments: const [
            ButtonSegment(value: StatisticsPeriod.week, label: Text('周')),
            ButtonSegment(value: StatisticsPeriod.month, label: Text('月')),
            ButtonSegment(value: StatisticsPeriod.year, label: Text('年')),
          ],
          selected: {period.period},
          onSelectionChanged: (s) {
            ref.read(statisticsPeriodProvider.notifier).state = buildStatisticsRange(s.first);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${period.from} ~ ${period.to}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kInkSecondary),
          ),
        ),
        const SizedBox(height: 12),
        asyncMetrics.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('加载失败: $e'),
          data: (m) {
            final total = m.presentCount + m.lateCount + m.absentCount;
            final attendRate = total > 0 ? (m.presentCount + m.lateCount) / total * 100 : 0.0;
            final screenWidth = MediaQuery.of(context).size.width;
            final aspectRatio = screenWidth < 360 ? 1.6 : 2.0;

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: aspectRatio,
              children: [
                _MetricCard('收入', '¥${m.totalFee.toStringAsFixed(0)}'),
                _MetricCard('出勤节数', '${m.presentCount + m.lateCount}节'),
                _MetricCard('活跃人数', '${m.activeStudentCount}人'),
                _MetricCard('出勤率', '${attendRate.toStringAsFixed(1)}%'),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'NotoSansSC',
                fontSize: 20,
                color: kPrimaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
