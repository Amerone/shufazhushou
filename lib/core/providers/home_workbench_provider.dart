import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dao/student_dao.dart' show StudentWithMeta;
import '../models/attendance.dart';
import '../services/home_workbench_service.dart';
import 'attendance_provider.dart';
import 'fee_summary_provider.dart';
import 'insight_provider.dart';
import 'student_provider.dart';
import '../../shared/constants.dart' show AttendanceStatus;

final homeWorkbenchServiceProvider = Provider(
  (ref) => const HomeWorkbenchService(),
);

final homeWorkbenchProvider = FutureProvider<List<HomeWorkbenchTask>>((
  ref,
) async {
  final dismissedDao = ref.read(dismissedInsightDaoProvider);
  final insightService = ref.read(insightServiceProvider);
  final workbenchService = ref.read(homeWorkbenchServiceProvider);

  final deleteExpiredFuture = dismissedDao.deleteExpired();
  final studentsWithMetaFuture = ref.watch(studentProvider.future);
  final monthAttendanceFuture = ref.watch(attendanceProvider.future);
  final allAttendanceFuture = ref.watch(allAttendanceByStudentProvider.future);
  final allPaymentsFuture = ref.watch(allPaymentsByStudentProvider.future);

  final dataFuture = Future.wait<Object?>([
    studentsWithMetaFuture,
    monthAttendanceFuture,
    allAttendanceFuture,
    allPaymentsFuture,
  ]);

  await Future.wait<void>([deleteExpiredFuture, dataFuture.then<void>((_) {})]);
  final dismissedKeysFuture = dismissedDao.getAllActiveKeys();

  final dataResults = await dataFuture;
  final studentsWithMeta = dataResults[0] as List<StudentWithMeta>;
  final students = studentsWithMeta
      .map((item) => item.student)
      .toList(growable: false);
  final displayNames = ref.read(studentDisplayNameMapProvider);
  final monthAttendance = dataResults[1] as List<Attendance>;
  final allAttendance = dataResults[2] as Map<String, List<Attendance>>;
  final allPayments = dataResults[3] as Map<String, double>;
  final dismissedKeys = await dismissedKeysFuture;
  final activeStudentCount = {
    for (final record in monthAttendance)
      if (record.status == AttendanceStatus.present.name ||
          record.status == AttendanceStatus.late.name ||
          record.status == AttendanceStatus.trial.name)
        record.studentId,
  }.length;

  final insights = insightService.buildInsights(
    students: students,
    displayNames: displayNames,
    allAttendance: allAttendance,
    allPayments: allPayments,
    dismissedKeys: dismissedKeys,
    activeStudentCount: activeStudentCount,
    activePeriodLabel: '本月',
    now: DateTime.now(),
  );

  return workbenchService.buildTasks(
    insights: insights,
    students: students,
    displayNames: displayNames,
    monthAttendance: monthAttendance,
  );
});
