import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/revenue_provider.dart';
import '../../../shared/theme.dart';

class RevenueChart extends ConsumerStatefulWidget {
  const RevenueChart({super.key});

  @override
  ConsumerState<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends ConsumerState<RevenueChart> {
  bool _showReceivable = true;
  bool _showReceived = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncRevenue = ref.watch(revenueProvider);

    return asyncRevenue.when(
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('加载失败: $e'),
      data: (data) {
        final months = <String>{
          ...data.monthlyReceivable.map((m) => m['month'] as String),
          ...data.monthlyReceived.map((m) => m['month'] as String),
        }.toList()
          ..sort();

        if (months.isEmpty) {
          return const SizedBox(height: 200, child: Center(child: Text('暂无数据')));
        }

        final receivableMap = {
          for (final m in data.monthlyReceivable)
            m['month'] as String: ((m['totalFee'] as num?) ?? 0).toDouble(),
        };
        final receivedMap = {
          for (final m in data.monthlyReceived)
            m['month'] as String: ((m['totalReceived'] as num?) ?? 0).toDouble(),
        };

        final spots1 = months
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), receivableMap[e.value] ?? 0))
            .toList();
        final spots2 = months
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), receivedMap[e.value] ?? 0))
            .toList();
        final totalReceivable = receivableMap.values.fold<double>(0, (sum, item) => sum + item);
        final totalReceived = receivedMap.values.fold<double>(0, (sum, item) => sum + item);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RevenueSummary(
                  label: '累计应收',
                  value: '¥${totalReceivable.toStringAsFixed(0)}',
                  color: kPrimaryBlue,
                ),
                _RevenueSummary(
                  label: '累计实收',
                  value: '¥${totalReceived.toStringAsFixed(0)}',
                  color: kGreen,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  lineTouchData: const LineTouchData(enabled: true),
                  minY: 0,
                  lineBarsData: [
                    if (_showReceivable)
                      LineChartBarData(
                        spots: spots1,
                        color: kPrimaryBlue,
                        isCurved: true,
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: kPrimaryBlue.withValues(alpha: 0.08),
                        ),
                        dotData: const FlDotData(show: false),
                      ),
                    if (_showReceived)
                      LineChartBarData(
                        spots: spots2,
                        color: kGreen,
                        isCurved: true,
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: kGreen.withValues(alpha: 0.08),
                        ),
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: months.length > 6 ? 2 : 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= months.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              months[i].substring(5),
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: kInkSecondary.withValues(alpha: 0.12),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Legend('应收', kPrimaryBlue, _showReceivable, () {
                  setState(() => _showReceivable = !_showReceivable);
                }),
                _Legend('实收', kGreen, _showReceived, () {
                  setState(() => _showReceived = !_showReceived);
                }),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RevenueSummary extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RevenueSummary({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontFamily: 'NotoSansSC',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _Legend(this.label, this.color, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 3,
            color: active ? color : kInkSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: active ? null : kInkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
