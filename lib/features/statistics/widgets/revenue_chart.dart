import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/revenue_provider.dart';
import '../../../shared/theme.dart';
import 'statistics_load_error.dart';

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
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 200,
        child: Center(
          child: StatisticsLoadError(
            message: buildStatisticsErrorMessage('收入走势', e),
            onRetry: () => ref.invalidate(revenueProvider),
          ),
        ),
      ),
      data: (data) {
        final months = <String>{
          ...data.monthlyReceivable.map((m) => m['month'] as String),
          ...data.monthlyReceived.map((m) => m['month'] as String),
        }.toList()..sort();

        if (months.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kInkSecondary.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.show_chart_outlined,
                  color: kInkSecondary.withValues(alpha: 0.72),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前周期暂无收入记录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kInkSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final receivableMap = {
          for (final m in data.monthlyReceivable)
            m['month'] as String: ((m['totalFee'] as num?) ?? 0).toDouble(),
        };
        final receivedMap = {
          for (final m in data.monthlyReceived)
            m['month'] as String: ((m['totalReceived'] as num?) ?? 0)
                .toDouble(),
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
        final chartSeries = _buildRevenueSeries(
          showReceivable: _showReceivable,
          showReceived: _showReceived,
          receivableSpots: spots1,
          receivedSpots: spots2,
        );
        final totalReceivable = receivableMap.values.fold<double>(
          0,
          (sum, item) => sum + item,
        );
        final totalReceived = receivedMap.values.fold<double>(
          0,
          (sum, item) => sum + item,
        );

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
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) => spots.map((spot) {
                        final label = chartSeries[spot.barIndex].label;
                        return LineTooltipItem(
                          '$label ¥${spot.y.toStringAsFixed(0)}',
                          theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ) ??
                              const TextStyle(color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                  minY: 0,
                  lineBarsData: [
                    for (final series in chartSeries)
                      LineChartBarData(
                        spots: series.spots,
                        color: series.color,
                        isCurved: true,
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: series.color.withValues(alpha: 0.08),
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
                          if (i < 0 || i >= months.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              months[i].substring(5),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, _) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            _compactMoney(value),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: kInkSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
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
                _Legend(
                  '应收',
                  kPrimaryBlue,
                  _showReceivable,
                  _showReceivable && !_showReceived,
                  () {
                    setState(() => _showReceivable = !_showReceivable);
                  },
                ),
                _Legend(
                  '实收',
                  kGreen,
                  _showReceived,
                  _showReceived && !_showReceivable,
                  () {
                    setState(() => _showReceived = !_showReceived);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RevenueSeries {
  final String label;
  final Color color;
  final List<FlSpot> spots;

  const _RevenueSeries({
    required this.label,
    required this.color,
    required this.spots,
  });
}

List<_RevenueSeries> _buildRevenueSeries({
  required bool showReceivable,
  required bool showReceived,
  required List<FlSpot> receivableSpots,
  required List<FlSpot> receivedSpots,
}) {
  return [
    if (showReceivable)
      _RevenueSeries(label: '应收', color: kPrimaryBlue, spots: receivableSpots),
    if (showReceived)
      _RevenueSeries(label: '实收', color: kGreen, spots: receivedSpots),
  ];
}

@visibleForTesting
List<String> revenueChartSeriesLabelsForTesting({
  required bool showReceivable,
  required bool showReceived,
}) {
  return _buildRevenueSeries(
    showReceivable: showReceivable,
    showReceived: showReceived,
    receivableSpots: const [],
    receivedSpots: const [],
  ).map((series) => series.label).toList();
}

String _compactMoney(double value) {
  if (value >= 10000) {
    final wan = value / 10000;
    return '${wan.toStringAsFixed(wan >= 10 ? 0 : 1)}万';
  }
  if (value >= 1000) {
    final thousand = value / 1000;
    return '${thousand.toStringAsFixed(thousand >= 10 ? 0 : 1)}k';
  }
  return value.toStringAsFixed(0);
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
  final bool locked;
  final VoidCallback onTap;
  const _Legend(this.label, this.color, this.active, this.locked, this.onTap);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: active,
      enabled: !locked,
      label: '$label${active ? '已显示' : '已隐藏'}',
      child: Tooltip(
        message: locked ? '至少保留一条曲线' : '切换$label曲线',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: locked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
          ),
        ),
      ),
    );
  }
}
