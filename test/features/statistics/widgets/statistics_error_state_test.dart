import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/providers/insight_provider.dart';
import 'package:moyun/core/providers/metrics_provider.dart';
import 'package:moyun/core/services/insight_aggregation_service.dart';
import 'package:moyun/features/statistics/widgets/insight_list.dart';
import 'package:moyun/features/statistics/widgets/metrics_grid.dart';
import 'package:moyun/features/statistics/widgets/statistics_load_error.dart';

void main() {
  test('statistics error helpers normalize exception prefixes', () {
    expect(formatStatisticsError(Exception('数据库连接失败')), '数据库连接失败');
    expect(
      buildStatisticsErrorMessage('核心指标', Exception('数据库连接失败')),
      '核心指标加载失败：数据库连接失败',
    );
    expect(
      buildStatisticsErrorMessage('核心指标', StateError('')),
      '核心指标加载失败，请稍后重试。',
    );
  });

  testWidgets('metrics grid error state allows retry', (tester) async {
    _FailingMetricsNotifier.buildCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [metricsProvider.overrideWith(_FailingMetricsNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(padding: EdgeInsets.all(16), child: MetricsGrid()),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.textContaining('核心指标加载失败'), findsOneWidget);
    expect(find.textContaining('数据库连接失败'), findsOneWidget);
    expect(_FailingMetricsNotifier.buildCount, 1);

    await tester.tap(find.text('重试'));
    await _settleUi(tester);

    expect(_FailingMetricsNotifier.buildCount, greaterThanOrEqualTo(2));
  });

  testWidgets('insight list error state allows retry', (tester) async {
    _FailingInsightNotifier.buildCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [insightProvider.overrideWith(_FailingInsightNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: InsightList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.textContaining('经营提醒加载失败'), findsOneWidget);
    expect(find.textContaining('提醒聚合失败'), findsOneWidget);
    expect(_FailingInsightNotifier.buildCount, 1);

    await tester.tap(find.text('重试'));
    await _settleUi(tester);

    expect(_FailingInsightNotifier.buildCount, greaterThanOrEqualTo(2));
  });
}

class _FailingMetricsNotifier extends MetricsNotifier {
  static int buildCount = 0;

  @override
  Future<MetricsData> build() async {
    buildCount += 1;
    throw Exception('数据库连接失败');
  }
}

class _FailingInsightNotifier extends InsightNotifier {
  static int buildCount = 0;

  @override
  Future<List<Insight>> build() async {
    buildCount += 1;
    throw Exception('提醒聚合失败');
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
