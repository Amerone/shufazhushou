import 'package:moyun/core/models/dismissed_insight.dart';
import 'package:moyun/core/services/dismissed_insight_policy.dart';
import 'package:moyun/shared/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DismissedInsightPolicy', () {
    test('debt and renewal use short retention', () {
      expect(
        DismissedInsightPolicy.retentionForInsight(InsightType.debt),
        const Duration(days: 3),
      );
      expect(
        DismissedInsightPolicy.retentionForInsight(InsightType.renewal),
        const Duration(days: 3),
      );
    });

    test('progress uses longer retention to reduce repeated noise', () {
      expect(
        DismissedInsightPolicy.retentionForInsight(InsightType.progress),
        const Duration(days: 14),
      );
    });

    test('isActive expires according to configured retention', () {
      final dismissedAt = DateTime.utc(2026, 3, 27).millisecondsSinceEpoch;
      final debtInsight = DismissedInsight(
        id: 'dismissed-1',
        insightType: 'debt',
        studentId: 'student-1',
        dismissedAt: dismissedAt,
      );
      final progressInsight = DismissedInsight(
        id: 'dismissed-2',
        insightType: 'progress',
        studentId: 'student-2',
        dismissedAt: dismissedAt,
      );

      expect(
        DismissedInsightPolicy.isActive(
          debtInsight,
          now: DateTime.utc(2026, 3, 29, 23, 59),
        ),
        isTrue,
      );
      expect(
        DismissedInsightPolicy.isActive(
          debtInsight,
          now: DateTime.utc(2026, 3, 30),
        ),
        isFalse,
      );
      expect(
        DismissedInsightPolicy.isActive(
          progressInsight,
          now: DateTime.utc(2026, 4, 8, 23, 59),
        ),
        isTrue,
      );
      expect(
        DismissedInsightPolicy.isActive(
          progressInsight,
          now: DateTime.utc(2026, 4, 10),
        ),
        isFalse,
      );
    });

    test('unknown types fall back to default retention', () {
      expect(
        DismissedInsightPolicy.retentionForType('unknown'),
        const Duration(days: 7),
      );
    });
  });
}
