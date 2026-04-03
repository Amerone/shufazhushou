import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StatisticsPeriod { week, month, year }

class StatisticsRange {
  final StatisticsPeriod period;
  final String from; // YYYY-MM-DD
  final String to; // YYYY-MM-DD

  const StatisticsRange({
    required this.period,
    required this.from,
    required this.to,
  });
}

String _pad(int n) => n.toString().padLeft(2, '0');
String _fmt(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

StatisticsRange buildStatisticsRangeForDate(
  StatisticsPeriod period,
  DateTime now,
) {
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

StatisticsRange buildStatisticsRange(StatisticsPeriod period) =>
    buildStatisticsRangeForDate(period, DateTime.now());

final statisticsClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  while (true) {
    await Future<void>.delayed(const Duration(minutes: 1));
    yield DateTime.now();
  }
});

final statisticsNowProvider = Provider<DateTime>((ref) {
  final now = ref.watch(statisticsClockProvider).valueOrNull;
  return now ?? DateTime.now();
});

final statisticsPeriodSelectionProvider = StateProvider<StatisticsPeriod>(
  (ref) => StatisticsPeriod.month,
);

final statisticsPeriodProvider = Provider<StatisticsRange>((ref) {
  final period = ref.watch(statisticsPeriodSelectionProvider);
  final now = ref.watch(statisticsNowProvider);
  return buildStatisticsRangeForDate(period, now);
});
