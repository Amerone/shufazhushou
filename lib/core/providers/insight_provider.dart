import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dao/dismissed_insight_dao.dart';
import '../models/student.dart';
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
    final studentDao = ref.read(studentDaoProvider);
    final attendanceDao = ref.read(attendanceDaoProvider);
    final paymentDao = ref.read(paymentDaoProvider);
    final dismissedDao = ref.read(dismissedInsightDaoProvider);
    final insightService = ref.read(insightServiceProvider);

    await dismissedDao.deleteExpired();

    final students = await studentDao.getAll();
    final displayNames = buildDisplayNameMap(students);
    final allAttendance = await attendanceDao.getAllGroupedByStudent();
    final allPayments = await paymentDao.getTotalByAllStudents();
    final dismissedKeys = await dismissedDao.getAllActiveKeys();

    final now = DateTime.now();
    final metrics = await attendanceDao.getMetrics(range.from, range.to);

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
