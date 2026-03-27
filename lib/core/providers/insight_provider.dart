import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dao/dismissed_insight_dao.dart';
import '../models/student.dart';
import '../services/insight_aggregation_service.dart';
import 'attendance_provider.dart';
import 'database_provider.dart';
import 'fee_summary_provider.dart';
import 'student_provider.dart';

final dismissedInsightDaoProvider =
    Provider((ref) => DismissedInsightDao(ref.watch(databaseProvider)));

final insightServiceProvider =
    Provider((ref) => const InsightAggregationService());

class InsightNotifier extends AsyncNotifier<List<Insight>> {
  @override
  Future<List<Insight>> build() async {
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
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final metrics = await attendanceDao.getMetrics(
      _formatDate(weekStart),
      _formatDate(now),
    );

    return insightService.buildInsights(
      students: students,
      displayNames: displayNames,
      allAttendance: allAttendance,
      allPayments: allPayments,
      dismissedKeys: dismissedKeys,
      weeklyActiveStudentCount:
          (metrics['activeStudentCount'] as num?)?.toInt() ?? 0,
      now: now,
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

final insightProvider =
    AsyncNotifierProvider<InsightNotifier, List<Insight>>(InsightNotifier.new);
