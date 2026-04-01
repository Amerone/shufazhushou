import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/dismissed_insight_dao.dart';
import 'package:moyun/core/database/dao/payment_dao.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/fee_summary_provider.dart';
import 'package:moyun/core/providers/insight_provider.dart';
import 'package:moyun/core/providers/statistics_period_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/services/insight_aggregation_service.dart';
import 'package:moyun/shared/constants.dart';

void main() {
  test(
    'InsightNotifier wires DAOs, cleanup and display names correctly',
    () async {
      const range = StatisticsRange(
        period: StatisticsPeriod.month,
        from: '2026-03-01',
        to: '2026-03-31',
      );
      final studentDao = _FakeStudentDao([
        const Student(
          id: 'student-1',
          name: 'Alex',
          parentName: 'Parent A',
          parentPhone: '13800000001',
          pricePerClass: 100,
          status: 'active',
          note: null,
          createdAt: 1,
          updatedAt: 1,
        ),
        const Student(
          id: 'student-2',
          name: 'Alex',
          parentName: 'Parent B',
          parentPhone: '13800000002',
          pricePerClass: 120,
          status: 'active',
          note: null,
          createdAt: 2,
          updatedAt: 2,
        ),
      ]);
      final attendanceDao = _FakeAttendanceDao(
        attendance: [
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
        groupedAttendance: {
          'student-1': [
            Attendance(
              id: 'attendance-0',
              studentId: 'student-1',
              date: '2026-02-20',
              startTime: '09:00',
              endTime: '10:00',
              status: 'present',
              priceSnapshot: 100,
              feeAmount: 100,
              createdAt: 0,
              updatedAt: 0,
            ),
          ],
        },
        metrics: const {'activeStudentCount': 2},
      );
      final paymentDao = _FakePaymentDao(const {
        'student-1': 300,
        'student-2': 0,
      });
      final dismissedDao = _FakeDismissedInsightDao(const {
        'renewal:student-1',
      });
      final spyService = _SpyInsightService(const [
        Insight(
          type: InsightType.progress,
          studentId: 'student-1',
          studentName: 'Alex\uFF08Parent A\uFF09',
          message: 'Progress trend improved',
          suggestion: 'Keep current practice rhythm.',
          calcLogic: 'Generated when one score improves across 3 records.',
          dataFreshness: '2026-03-27 09:00',
        ),
      ]);

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
      container.read(statisticsPeriodProvider.notifier).state = range;

      final insights = await container.read(insightProvider.future);

      expect(dismissedDao.deleteExpiredCalled, isTrue);
      expect(dismissedDao.getAllActiveKeysCalled, isTrue);
      expect(insights, hasLength(1));
      expect(insights.single.type, InsightType.progress);
      expect(spyService.capturedDismissedKeys, const {'renewal:student-1'});
      expect(spyService.capturedActiveStudentCount, 2);
      expect(spyService.capturedActivePeriodLabel, '\u672C\u6708');
      expect(
        spyService.capturedDisplayNames['student-1'],
        'Alex\uFF08Parent A\uFF09',
      );
      expect(
        spyService.capturedDisplayNames['student-2'],
        'Alex\uFF08Parent B\uFF09',
      );
      expect(spyService.capturedAllPayments['student-1'], 300);
      expect(
        spyService.capturedAllAttendance['student-1']?.single.date,
        '2026-02-20',
      );
      expect(attendanceDao.groupedByStudentCalled, isTrue);
      expect(attendanceDao.metricsFrom, isNotNull);
      expect(attendanceDao.metricsTo, isNotNull);
      expect(attendanceDao.metricsFrom, range.from);
      expect(attendanceDao.metricsTo, range.to);
      expect(paymentDao.totalByAllStudentsCalled, isTrue);
    },
  );
}

class _FakeStudentDao extends StudentDao {
  final List<Student> students;

  _FakeStudentDao(this.students) : super(DatabaseHelper.instance);

  @override
  Future<List<Student>> getAll() async => students;
}

class _FakeAttendanceDao extends AttendanceDao {
  final List<Attendance> attendance;
  final Map<String, List<Attendance>> groupedAttendance;
  final Map<String, dynamic> metrics;
  bool groupedByStudentCalled = false;
  String? metricsFrom;
  String? metricsTo;

  _FakeAttendanceDao({
    required this.attendance,
    required this.groupedAttendance,
    required this.metrics,
  }) : super(DatabaseHelper.instance);

  @override
  Future<Map<String, List<Attendance>>> getAllGroupedByStudent() async {
    groupedByStudentCalled = true;
    return {
      for (final entry in groupedAttendance.entries)
        entry.key: List<Attendance>.from(entry.value),
      if (!groupedAttendance.containsKey('student-1'))
        'student-1': List<Attendance>.from(attendance),
    };
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
  bool totalByAllStudentsCalled = false;

  _FakePaymentDao(this.totalsByStudent) : super(DatabaseHelper.instance);

  @override
  Future<Map<String, double>> getTotalByAllStudents() async {
    totalByAllStudentsCalled = true;
    return totalsByStudent;
  }
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
  int capturedActiveStudentCount = 0;
  String capturedActivePeriodLabel = '';
  DateTime? capturedNow;

  _SpyInsightService(this._result);

  @override
  List<Insight> buildInsights({
    required List<Student> students,
    required Map<String, String> displayNames,
    required Map<String, List<Attendance>> allAttendance,
    required Map<String, double> allPayments,
    required Set<String> dismissedKeys,
    required int activeStudentCount,
    String activePeriodLabel = '\u672C\u5468',
    DateTime? now,
  }) {
    capturedStudents = students;
    capturedDisplayNames = displayNames;
    capturedAllAttendance = allAttendance;
    capturedAllPayments = allPayments;
    capturedDismissedKeys = dismissedKeys;
    capturedActiveStudentCount = activeStudentCount;
    capturedActivePeriodLabel = activePeriodLabel;
    capturedNow = now;
    return _result;
  }
}
