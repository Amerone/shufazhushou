import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/metrics_provider.dart';
import '../../../shared/theme.dart';

class MetricsGrid extends ConsumerWidget {
  const MetricsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMetrics = ref.watch(metricsProvider);

    return asyncMetrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
      data: (m) {
        final total = m.presentCount + m.lateCount + m.absentCount;
        final attendRate = total > 0
            ? (m.presentCount + m.lateCount) / total * 100
            : 0.0;
        final metricItems = [
          _MetricData(
            '实收',
            '¥${m.totalReceived.toStringAsFixed(0)}',
            Icons.account_balance_wallet_outlined,
            kSealRed,
          ),
          _MetricData(
            '应收',
            '¥${m.totalReceivable.toStringAsFixed(0)}',
            Icons.payments_outlined,
            kPrimaryBlue,
          ),
          _MetricData(
            '出勤节数',
            '${m.presentCount + m.lateCount}节',
            Icons.event_available_outlined,
            kGreen,
          ),
          _MetricData(
            '活跃人数',
            '${m.activeStudentCount}人',
            Icons.groups_2_outlined,
            kSealRed,
          ),
          _MetricData(
            '出勤率',
            '${attendRate.toStringAsFixed(1)}%',
            Icons.trending_up_outlined,
            kOrange,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 840
                ? 4
                : width >= 520
                ? 2
                : 1;
            final itemWidth = (width - 12 * (columns - 1)) / columns;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metricItems
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: _MetricCard(data: item),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData(this.label, this.value, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: data.color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(data.label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'NotoSansSC',
              fontSize: 20,
              color: data.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
