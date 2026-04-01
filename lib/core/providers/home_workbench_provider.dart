import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/constants.dart';
import '../models/student.dart';
import '../services/home_workbench_service.dart';
import 'attendance_provider.dart';
import 'fee_summary_provider.dart';
import 'insight_provider.dart';
import 'student_provider.dart';

final homeWorkbenchServiceProvider = Provider(
  (ref) => const HomeWorkbenchService(),
);

final homeWorkbenchProvider = FutureProvider<List<HomeWorkbenchTask>>((
  ref,
) async {
  final month = ref.watch(selectedMonthProvider);
  final from = formatDate(DateTime(month.year, month.month, 1));
  final to = formatDate(DateTime(month.year, month.month + 1, 0));
  final studentDao = ref.read(studentDaoProvider);
  final attendanceDao = ref.read(attendanceDaoProvider);
  final paymentDao = ref.read(paymentDaoProvider);
  final dismissedDao = ref.read(dismissedInsightDaoProvider);
  final insightService = ref.read(insightServiceProvider);
  final workbenchService = ref.read(homeWorkbenchServiceProvider);

  await dismissedDao.deleteExpired();

  final students = await studentDao.getAll();
  final displayNames = buildDisplayNameMap(students);
  final attendance = await attendanceDao.getByDateRange(from, to);
  final allAttendance = await attendanceDao.getAllGroupedByStudent();
  final allPayments = await paymentDao.getTotalByAllStudents();
  final dismissedKeys = await dismissedDao.getAllActiveKeys();
  final metrics = await attendanceDao.getMetrics(from, to);

  final insights = insightService.buildInsights(
    students: students,
    displayNames: displayNames,
    allAttendance: allAttendance,
    allPayments: allPayments,
    dismissedKeys: dismissedKeys,
    activeStudentCount: (metrics['activeStudentCount'] as num?)?.toInt() ?? 0,
    activePeriodLabel: '本月',
    now: DateTime.now(),
  );

  return workbenchService.buildTasks(
    insights: insights,
    students: students,
    displayNames: displayNames,
    monthAttendance: attendance,
  );
});
