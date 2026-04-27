import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/constants.dart' show AttendanceStatus;
import '../database/dao/student_dao.dart' show StudentWithMeta;
import '../models/attendance.dart';
import '../models/student_insight_facts.dart';
import '../services/home_workbench_service.dart';
import 'attendance_provider.dart';
import 'clock_provider.dart';
import 'fee_summary_provider.dart';
import 'insight_provider.dart';
import 'student_provider.dart';

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
  final attendanceFactsFuture = ref.watch(
    attendanceInsightFactsByStudentProvider.future,
  );
  final allPaymentsFuture = ref.watch(allPaymentsByStudentProvider.future);

  final dataFuture = Future.wait<Object?>([
    studentsWithMetaFuture,
    monthAttendanceFuture,
    attendanceFactsFuture,
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
  final attendanceFacts =
      dataResults[2] as Map<String, StudentAttendanceInsightFacts>;
  final allPayments = dataResults[3] as Map<String, double>;
  final dismissedKeys = await dismissedKeysFuture;
  final activeStudentCount = {
    for (final record in monthAttendance)
      if (record.status == AttendanceStatus.present.name ||
          record.status == AttendanceStatus.late.name ||
          record.status == AttendanceStatus.trial.name)
        record.studentId,
  }.length;

  final insights = insightService.buildInsightsFromFacts(
    students: students,
    displayNames: displayNames,
    factsByStudent: attendanceFacts,
    allPayments: allPayments,
    dismissedKeys: dismissedKeys,
    activeStudentCount: activeStudentCount,
    activePeriodLabel: '本月',
    now: ref.read(appClockProvider).now(),
  );

  return workbenchService.buildTasks(
    insights: insights,
    students: students,
    displayNames: displayNames,
    monthAttendance: monthAttendance,
    dismissedKeys: dismissedKeys,
  );
});
