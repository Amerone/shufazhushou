import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/constants.dart';
import '../database/dao/dismissed_insight_dao.dart';
import '../models/student.dart';
import 'attendance_provider.dart';
import 'database_provider.dart';
import 'fee_summary_provider.dart';
import 'student_provider.dart';

final dismissedInsightDaoProvider = Provider((ref) =>
    DismissedInsightDao(ref.watch(databaseProvider)));

class Insight {
  final InsightType type;
  final String? studentId;
  final String studentName;
  final String message;

  const Insight({
    required this.type,
    this.studentId,
    required this.studentName,
    required this.message,
  });
}

class InsightNotifier extends AsyncNotifier<List<Insight>> {
  @override
  Future<List<Insight>> build() async {
    final studentDao = ref.read(studentDaoProvider);
    final attendanceDao = ref.read(attendanceDaoProvider);
    final paymentDao = ref.read(paymentDaoProvider);
    final dismissedDao = ref.read(dismissedInsightDaoProvider);

    // Clean up expired dismissed insights
    await dismissedDao.deleteExpired();

    // Batch load all data (~4 queries instead of N*3)
    final students = await studentDao.getAll();
    final displayNames = buildDisplayNameMap(students);
    final allAttendance = await attendanceDao.getAllGroupedByStudent();
    final allPayments = await paymentDao.getTotalByAllStudents();
    final dismissedKeys = await dismissedDao.getAllActiveKeys();

    final insights = <Insight>[];

    for (final student in students) {
      final records = allAttendance[student.id] ?? [];
      final received = allPayments[student.id] ?? 0.0;

      // 欠费提醒
      if (!dismissedKeys.contains('debt:${student.id}')) {
        final receivable = records.fold<double>(0, (s, a) => s + a.feeAmount);
        final balance = received - receivable;
        if (balance < 0) {
          insights.add(Insight(
            type: InsightType.debt,
            studentId: student.id,
            studentName: displayNames[student.id] ?? student.name,
            message: '欠费 ¥${(-balance).toStringAsFixed(2)}',
          ));
        }
      }

      // 流失预警
      if (student.status == 'active') {
        if (!dismissedKeys.contains('churn:${student.id}')) {
          final activeDates = records
              .where((r) => r.status == 'present' || r.status == 'late')
              .map((r) => r.date);
          final lastActive = activeDates.isEmpty
              ? null
              : activeDates.reduce((a, b) => b.compareTo(a) > 0 ? b : a);
          if (lastActive != null) {
            final last = DateTime.parse(lastActive);
            if (DateTime.now().difference(last).inDays >= kChurnDays) {
              insights.add(Insight(
                type: InsightType.churn,
                studentId: student.id,
                studentName: displayNames[student.id] ?? student.name,
                message: '${DateTime.now().difference(last).inDays} 天未出勤',
              ));
            }
          }
        }
      }

      // 试听转化
      if (!dismissedKeys.contains('trial:${student.id}')) {
        final hasTrial = records.any((r) => r.status == 'trial');
        final hasFormal = records
            .any((r) => r.status == 'present' || r.status == 'late');
        if (hasTrial && !hasFormal) {
          insights.add(Insight(
            type: InsightType.trial,
            studentId: student.id,
            studentName: displayNames[student.id] ?? student.name,
            message: '有试听记录，尚未转正式',
          ));
        }
      }
    }

    // 高峰提示（全局，不关联学生）
    if (!dismissedKeys.contains('peak:')) {
      final now = DateTime.now();
      final weekStart =
          now.subtract(Duration(days: now.weekday - 1));
      final from = formatDate(weekStart);
      final to = formatDate(now);
      final metrics = await attendanceDao.getMetrics(from, to);
      final activeCount = (metrics['activeStudentCount'] as num).toInt();
      if (activeCount >= kPeakThreshold) {
        insights.add(const Insight(
          type: InsightType.peak,
          studentName: '',
          message: '本周出勤人数较多，注意课堂安排',
        ));
      }
    }

    return insights;
  }
}

final insightProvider =
    AsyncNotifierProvider<InsightNotifier, List<Insight>>(InsightNotifier.new);
