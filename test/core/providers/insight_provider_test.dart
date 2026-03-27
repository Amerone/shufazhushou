import 'package:calligraphy_assistant/core/database/dao/attendance_dao.dart';
import 'package:calligraphy_assistant/core/database/dao/dismissed_insight_dao.dart';
import 'package:calligraphy_assistant/core/database/dao/payment_dao.dart';
import 'package:calligraphy_assistant/core/database/dao/student_dao.dart';
import 'package:calligraphy_assistant/core/database/database_helper.dart';
import 'package:calligraphy_assistant/core/models/attendance.dart';
import 'package:calligraphy_assistant/core/models/student.dart';
import 'package:calligraphy_assistant/core/providers/attendance_provider.dart';
import 'package:calligraphy_assistant/core/providers/fee_summary_provider.dart';
import 'package:calligraphy_assistant/core/providers/insight_provider.dart';
import 'package:calligraphy_assistant/core/providers/student_provider.dart';
import 'package:calligraphy_assistant/core/services/insight_aggregation_service.dart';
import 'package:calligraphy_assistant/shared/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InsightNotifier wires DAOs, cleanup and display names correctly', () async {
    final studentDao = _FakeStudentDao([
      const Student(
        id: 'student-1',
        name: '张三',
        parentName: '李女士',
        parentPhone: '13800000001',
        pricePerClass: 100,
        status: 'active',
        note: null,
        createdAt: 1,
        updatedAt: 1,
      ),
      const Student(
        id: 'student-2',
        name: '张三',
        parentName: '王女士',
        parentPhone: '13800000002',
        pricePerClass: 120,
        status: 'active',
        note: null,
        createdAt: 2,
        updatedAt: 2,
      ),
    ]);
    final attendanceDao = _FakeAttendanceDao(
      groupedAttendance: {
        'student-1': [
          Attendance(
            id: 'attendance-1',
            studentId: 'student-1',
            date: '2026-03-25',
            startTime: '09:00',
            endTime: '10:00',
            status: 'present',
            priceSnapshot: 100,
            feeAmount: 100,
            createdAt: 1,
            updatedAt: 1,
          ),
        ],
      },
      metrics: const {'activeStudentCount': 2},
    );
    final paymentDao = _FakePaymentDao(
      const {'student-1': 300, 'student-2': 0},
    );
    final dismissedDao = _FakeDismissedInsightDao(
      const {'renewal:student-1'},
    );
    final spyService = _SpyInsightService(
      const [
        Insight(
          type: InsightType.progress,
          studentId: 'student-1',
          studentName: '张三（李女士）',
          message: '近 3 次评分持续提升：笔画质量',
          suggestion: '建议生成成长快照并同步家长，延续当前训练节奏。',
          calcLogic: '在最近 3 次有效评分记录中，至少一个维度连续递增时触发。',
          dataFreshness: '2026-03-27 09:00',
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        studentDaoProvider.overrideWithValue(studentDao),
        attendanceDaoProvider.overrideWithValue(attendanceDao),
        paymentDaoProvider.overrideWithValue(paymentDao),
        dismissedInsightDaoProvider.overrideWithValue(dismissedDao),
        insightServiceProvider.overrideWithValue(spyService),
      ],
    );
    addTearDown(container.dispose);

    final insights = await container.read(insightProvider.future);

    expect(dismissedDao.deleteExpiredCalled, isTrue);
    expect(dismissedDao.getAllActiveKeysCalled, isTrue);
    expect(insights, hasLength(1));
    expect(insights.single.type, InsightType.progress);
    expect(spyService.capturedDismissedKeys, const {'renewal:student-1'});
    expect(spyService.capturedWeeklyActiveStudentCount, 2);
    expect(spyService.capturedDisplayNames['student-1'], '张三（李女士）');
    expect(spyService.capturedDisplayNames['student-2'], '张三（王女士）');
    expect(spyService.capturedAllPayments['student-1'], 300);
    expect(spyService.capturedAllAttendance['student-1'], hasLength(1));
    expect(attendanceDao.metricsFrom, isNotNull);
    expect(attendanceDao.metricsTo, isNotNull);

    final capturedNow = spyService.capturedNow!;
    final expectedWeekStart =
        capturedNow.subtract(Duration(days: capturedNow.weekday - 1));
    expect(attendanceDao.metricsFrom, _formatDate(expectedWeekStart));
    expect(attendanceDao.metricsTo, _formatDate(capturedNow));
  });
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _FakeStudentDao extends StudentDao {
  final List<Student> students;

  _FakeStudentDao(this.students) : super(DatabaseHelper.instance);

  @override
  Future<List<Student>> getAll() async => students;
}

class _FakeAttendanceDao extends AttendanceDao {
  final Map<String, List<Attendance>> groupedAttendance;
  final Map<String, dynamic> metrics;
  String? metricsFrom;
  String? metricsTo;

  _FakeAttendanceDao({
    required this.groupedAttendance,
    required this.metrics,
  }) : super(DatabaseHelper.instance);

  @override
  Future<Map<String, List<Attendance>>> getAllGroupedByStudent() async {
    return groupedAttendance;
  }

  @override
  Future<Map<String, dynamic>> getMetrics(String from, String to) async {
    metricsFrom = from;
    metricsTo = to;
    return metrics;
  }
}

class _FakePaymentDao extends PaymentDao {
  final Map<String, double> totalsByStudent;

  _FakePaymentDao(this.totalsByStudent) : super(DatabaseHelper.instance);

  @override
  Future<Map<String, double>> getTotalByAllStudents() async => totalsByStudent;
}

class _FakeDismissedInsightDao extends DismissedInsightDao {
  final Set<String> activeKeys;
  bool deleteExpiredCalled = false;
  bool getAllActiveKeysCalled = false;

  _FakeDismissedInsightDao(this.activeKeys) : super(DatabaseHelper.instance);

  @override
  Future<void> deleteExpired({DateTime? now}) async {
    deleteExpiredCalled = true;
  }

  @override
  Future<Set<String>> getAllActiveKeys({DateTime? now}) async {
    getAllActiveKeysCalled = true;
    return activeKeys;
  }
}

class _SpyInsightService extends InsightAggregationService {
  final List<Insight> _result;
  List<Student> capturedStudents = const [];
  Map<String, String> capturedDisplayNames = const {};
  Map<String, List<Attendance>> capturedAllAttendance = const {};
  Map<String, double> capturedAllPayments = const {};
  Set<String> capturedDismissedKeys = const {};
  int capturedWeeklyActiveStudentCount = 0;
  DateTime? capturedNow;

  _SpyInsightService(this._result);

  @override
  List<Insight> buildInsights({
    required List<Student> students,
    required Map<String, String> displayNames,
    required Map<String, List<Attendance>> allAttendance,
    required Map<String, double> allPayments,
    required Set<String> dismissedKeys,
    required int weeklyActiveStudentCount,
    DateTime? now,
  }) {
    capturedStudents = students;
    capturedDisplayNames = displayNames;
    capturedAllAttendance = allAttendance;
    capturedAllPayments = allPayments;
    capturedDismissedKeys = dismissedKeys;
    capturedWeeklyActiveStudentCount = weeklyActiveStudentCount;
    capturedNow = now;
    return _result;
  }
}
