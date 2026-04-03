import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/providers/statistics_period_provider.dart';

void main() {
  test('buildStatisticsRangeForDate computes stable week month and year', () {
    final now = DateTime(2026, 1, 2);

    expect(
      buildStatisticsRangeForDate(StatisticsPeriod.week, now),
      isA<StatisticsRange>()
          .having((range) => range.from, 'from', '2025-12-29')
          .having((range) => range.to, 'to', '2026-01-04'),
    );
    expect(
      buildStatisticsRangeForDate(StatisticsPeriod.month, now),
      isA<StatisticsRange>()
          .having((range) => range.from, 'from', '2026-01-01')
          .having((range) => range.to, 'to', '2026-01-31'),
    );
    expect(
      buildStatisticsRangeForDate(StatisticsPeriod.year, now),
      isA<StatisticsRange>()
          .having((range) => range.from, 'from', '2026-01-01')
          .having((range) => range.to, 'to', '2026-12-31'),
    );
  });

  test(
    'statisticsPeriodProvider derives range from selected period and now',
    () {
      final container = ProviderContainer(
        overrides: [
          statisticsNowProvider.overrideWith((ref) => DateTime(2026, 4, 3)),
        ],
      );
      addTearDown(container.dispose);

      container.read(statisticsPeriodSelectionProvider.notifier).state =
          StatisticsPeriod.year;

      final range = container.read(statisticsPeriodProvider);

      expect(range.period, StatisticsPeriod.year);
      expect(range.from, '2026-01-01');
      expect(range.to, '2026-12-31');
    },
  );
}
