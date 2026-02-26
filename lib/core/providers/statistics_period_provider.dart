import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StatisticsPeriod { week, month, year }

class StatisticsRange {
  final StatisticsPeriod period;
  final String from; // YYYY-MM-DD
  final String to;   // YYYY-MM-DD

  const StatisticsRange({
    required this.period,
    required this.from,
    required this.to,
  });
}

String _pad(int n) => n.toString().padLeft(2, '0');
String _fmt(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

StatisticsRange _buildRange(StatisticsPeriod period) {
  final now = DateTime.now();
  switch (period) {
    case StatisticsPeriod.week:
      final start = now.subtract(Duration(days: now.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return StatisticsRange(period: period, from: _fmt(start), to: _fmt(end));
    case StatisticsPeriod.month:
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      return StatisticsRange(period: period, from: _fmt(start), to: _fmt(end));
    case StatisticsPeriod.year:
      final start = DateTime(now.year, 1, 1);
      final end = DateTime(now.year, 12, 31);
      return StatisticsRange(period: period, from: _fmt(start), to: _fmt(end));
  }
}

final statisticsPeriodProvider =
    StateProvider<StatisticsRange>((ref) => _buildRange(StatisticsPeriod.month));
