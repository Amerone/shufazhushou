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

    final students = await studentDao.getAll();
    final displayNames = buildDisplayNameMap(students);
    final insights = <Insight>[];

    for (final student in students) {
      // Lazy cache for attendance records per student
      List<dynamic>? records;

      // 欠费提醒
      final dismissed = await dismissedDao.find('debt', student.id);
      if (dismissed == null) {
        records ??= await attendanceDao
            .getByStudentAndDateRange(student.id, null, null);
        final receivable = records.fold<double>(0, (s, a) => s + a.feeAmount);
        final received =
            await paymentDao.getTotalByStudentAndDateRange(student.id, null, null);
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
        final churnDismissed =
            await dismissedDao.find('churn', student.id);
        if (churnDismissed == null) {
          records ??= await attendanceDao.getByStudentAndDateRange(
              student.id, null, null);
          final lastActive = records
              .where((r) => r.status == 'present' || r.status == 'late')
              .map((r) => r.date)
              .fold<String?>('', (a, b) => (a == null || b.compareTo(a) > 0) ? b : a);
          if (lastActive != null && lastActive.isNotEmpty) {
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
      final trialDismissed =
          await dismissedDao.find('trial', student.id);
      if (trialDismissed == null) {
        records ??= await attendanceDao
            .getByStudentAndDateRange(student.id, null, null);
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
    final peakDismissed = await dismissedDao.find('peak', null);
    if (peakDismissed == null) {
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
