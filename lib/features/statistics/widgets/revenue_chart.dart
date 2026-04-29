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
  RevenueData? _cachedRevenueData;
  _RevenueChartSnapshot? _cachedSnapshot;

  _RevenueChartSnapshot _snapshotFor(RevenueData data) {
    final cached = _cachedSnapshot;
    if (cached != null && identical(_cachedRevenueData, data)) {
      return cached;
    }
    final snapshot = _RevenueChartSnapshot.fromData(data);
    _cachedRevenueData = data;
    _cachedSnapshot = snapshot;
    return snapshot;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncRevenue = ref.watch(revenueProvider);

    return asyncRevenue.when(
      loading: () => Semantics(
        container: true,
        liveRegion: true,
        label: '\u6536\u5165\u8d70\u52bf\u52a0\u8f7d\u4e2d',
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Semantics(
        container: true,
        liveRegion: true,
        child: SizedBox(
          height: 200,
          child: Center(
            child: StatisticsLoadError(
              message: buildStatisticsErrorMessage('收入走势', e),
              onRetry: () => ref.invalidate(revenueProvider),
            ),
          ),
        ),
      ),
      data: (data) {
        final snapshot = _snapshotFor(data);

        if (snapshot.months.isEmpty) {
          return Semantics(
            container: true,
            liveRegion: true,
            label:
                '\u5f53\u524d\u5468\u671f\u6682\u65e0\u6536\u5165\u8bb0\u5f55',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: kInkSecondary.withValues(alpha: 0.08),
                ),
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
                    '暂无收入记录',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: kInkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final chartSeries = _buildRevenueSeries(
          showReceivable: _showReceivable,
          showReceived: _showReceived,
          receivableSpots: snapshot.receivableSpots,
          receivedSpots: snapshot.receivedSpots,
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
                  value: '¥${snapshot.totalReceivable.toStringAsFixed(0)}',
                  color: kPrimaryBlue,
                ),
                _RevenueSummary(
                  label: '累计实收',
                  value: '¥${snapshot.totalReceived.toStringAsFixed(0)}',
                  color: kGreen,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              container: true,
              label:
                  '\u6536\u5165\u8d70\u52bf\u56fe\uff0c\u5c55\u793a\u5f53\u524d\u5468\u671f\u7684\u5e94\u6536\u548c\u5b9e\u6536\u6708\u5ea6\u8d8b\u52bf',
              child: SizedBox(
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
                          interval: snapshot.months.length > 6 ? 2 : 1,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= snapshot.months.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                snapshot.months[i].substring(5),
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

class _RevenueChartSnapshot {
  final List<String> months;
  final List<FlSpot> receivableSpots;
  final List<FlSpot> receivedSpots;
  final double totalReceivable;
  final double totalReceived;

  const _RevenueChartSnapshot({
    required this.months,
    required this.receivableSpots,
    required this.receivedSpots,
    required this.totalReceivable,
    required this.totalReceived,
  });

  factory _RevenueChartSnapshot.fromData(RevenueData data) {
    final receivableMap = <String, double>{};
    for (final monthData in data.monthlyReceivable) {
      receivableMap[monthData['month'] as String] =
          ((monthData['totalFee'] as num?) ?? 0).toDouble();
    }

    final receivedMap = <String, double>{};
    for (final monthData in data.monthlyReceived) {
      receivedMap[monthData['month'] as String] =
          ((monthData['totalReceived'] as num?) ?? 0).toDouble();
    }

    final months = <String>{
      ...receivableMap.keys,
      ...receivedMap.keys,
    }.toList(growable: false)..sort();
    final receivableSpots = <FlSpot>[];
    final receivedSpots = <FlSpot>[];
    var totalReceivable = 0.0;
    var totalReceived = 0.0;

    for (var index = 0; index < months.length; index++) {
      final month = months[index];
      final receivable = receivableMap[month] ?? 0;
      final received = receivedMap[month] ?? 0;
      totalReceivable += receivable;
      totalReceived += received;
      receivableSpots.add(FlSpot(index.toDouble(), receivable));
      receivedSpots.add(FlSpot(index.toDouble(), received));
    }

    return _RevenueChartSnapshot(
      months: months,
      receivableSpots: receivableSpots,
      receivedSpots: receivedSpots,
      totalReceivable: totalReceivable,
      totalReceived: totalReceived,
    );
  }
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontFamily: 'NotoSansSC',
                fontWeight: FontWeight.w700,
              ),
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
      hint: locked
          ? '\u81f3\u5c11\u4fdd\u7559\u4e00\u6761\u6536\u5165\u66f2\u7ebf'
          : '\u70b9\u6309\u5207\u6362$label\u66f2\u7ebf',
      onTap: locked ? null : onTap,
      label: '$label${active ? '已显示' : '已隐藏'}',
      child: Tooltip(
        message: locked ? '至少保留一条曲线' : '切换$label曲线',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: locked ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
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
