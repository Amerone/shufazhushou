import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dao/dismissed_insight_dao.dart';
import '../database/dao/student_dao.dart' show StudentWithMeta;
import '../models/attendance.dart';
import '../services/insight_aggregation_service.dart';
import 'attendance_provider.dart';
import 'database_provider.dart';
import 'fee_summary_provider.dart';
import 'statistics_period_provider.dart';
import 'student_provider.dart';

final dismissedInsightDaoProvider = Provider(
  (ref) => DismissedInsightDao(ref.watch(databaseProvider)),
);

final insightServiceProvider = Provider(
  (ref) => const InsightAggregationService(),
);

class InsightNotifier extends AsyncNotifier<List<Insight>> {
  @override
  Future<List<Insight>> build() async {
    final range = ref.watch(statisticsPeriodProvider);
    final attendanceDao = ref.read(attendanceDaoProvider);
    final dismissedDao = ref.read(dismissedInsightDaoProvider);
    final insightService = ref.read(insightServiceProvider);

    final deleteExpiredFuture = dismissedDao.deleteExpired();
    final studentsWithMetaFuture = ref.watch(studentProvider.future);
    final allAttendanceFuture = ref.watch(
      allAttendanceByStudentProvider.future,
    );
    final allPaymentsFuture = ref.watch(allPaymentsByStudentProvider.future);
    final metricsFuture = attendanceDao.getMetrics(range.from, range.to);

    final dataFuture = Future.wait<Object?>([
      studentsWithMetaFuture,
      allAttendanceFuture,
      allPaymentsFuture,
      metricsFuture,
    ]);

    await Future.wait<void>([
      deleteExpiredFuture,
      dataFuture.then<void>((_) {}),
    ]);
    final dismissedKeysFuture = dismissedDao.getAllActiveKeys();

    final dataResults = await dataFuture;
    final studentsWithMeta = dataResults[0] as List<StudentWithMeta>;
    final students = studentsWithMeta
        .map((item) => item.student)
        .toList(growable: false);
    final displayNames = ref.read(studentDisplayNameMapProvider);
    final allAttendance = dataResults[1] as Map<String, List<Attendance>>;
    final allPayments = dataResults[2] as Map<String, double>;
    final dismissedKeys = await dismissedKeysFuture;

    final now = DateTime.now();
    final metrics = dataResults[3] as Map<String, dynamic>;

    return insightService.buildInsights(
      students: students,
      displayNames: displayNames,
      allAttendance: allAttendance,
      allPayments: allPayments,
      dismissedKeys: dismissedKeys,
      activeStudentCount: (metrics['activeStudentCount'] as num?)?.toInt() ?? 0,
      activePeriodLabel: _periodLabel(range.period),
      now: now,
    );
  }

  String _periodLabel(StatisticsPeriod period) {
    switch (period) {
      case StatisticsPeriod.week:
        return '本周';
      case StatisticsPeriod.month:
        return '本月';
      case StatisticsPeriod.year:
        return '本年';
    }
  }
}

final insightProvider = AsyncNotifierProvider<InsightNotifier, List<Insight>>(
  InsightNotifier.new,
);
