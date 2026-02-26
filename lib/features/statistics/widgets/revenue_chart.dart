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

        return Column(
          children: [
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineTouchData: const LineTouchData(enabled: true),
                  lineBarsData: [
                    if (_showReceivable)
                      LineChartBarData(
                        spots: spots1,
                        color: kPrimaryBlue,
                        dotData: const FlDotData(show: false),
                      ),
                    if (_showReceived)
                      LineChartBarData(
                        spots: spots2,
                        color: kGreen,
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
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend('应收', kPrimaryBlue, _showReceivable, () {
                  setState(() => _showReceivable = !_showReceivable);
                }),
                const SizedBox(width: 16),
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
