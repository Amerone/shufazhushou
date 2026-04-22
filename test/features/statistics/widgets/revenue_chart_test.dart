import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/features/statistics/widgets/revenue_chart.dart';

void main() {
  test('revenue tooltip labels follow visible series order', () {
    expect(
      revenueChartSeriesLabelsForTesting(
        showReceivable: false,
        showReceived: true,
      ),
      ['实收'],
    );

    expect(
      revenueChartSeriesLabelsForTesting(
        showReceivable: true,
        showReceived: true,
      ),
      ['应收', '实收'],
    );
  });
}
