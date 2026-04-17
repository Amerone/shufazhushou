import '../../shared/constants.dart';
import '../models/dismissed_insight.dart';

class DismissedInsightPolicy {
  const DismissedInsightPolicy._();

  static const Duration _shortRetention = Duration(days: 3);
  static const Duration _defaultRetention = Duration(days: 7);
  static const Duration _progressRetention = Duration(days: 14);

  static Duration retentionForType(String insightType) {
    switch (insightType) {
      case 'debt':
      case 'renewal':
        return _shortRetention;
      case 'churn':
      case 'peak':
      case 'trial':
        return _defaultRetention;
      case 'progress':
        return _progressRetention;
      default:
        return _defaultRetention;
    }
  }

  static Duration retentionForInsight(InsightType type) {
    return retentionForType(type.name);
  }

  static bool isActive(DismissedInsight insight, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(
      insight.dismissedAt,
    );
    final expiresAt = dismissedAt.add(retentionForType(insight.insightType));
    return currentTime.isBefore(expiresAt);
  }
}
