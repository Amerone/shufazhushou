import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/dismissed_insight_dao.dart';
import 'package:moyun/core/database/dao/payment_dao.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/business_data_summary.dart';
import 'package:moyun/core/models/data_insight_result.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/ai_provider.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/fee_summary_provider.dart';
import 'package:moyun/core/providers/insight_provider.dart';
import 'package:moyun/core/providers/statistics_period_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/services/data_insight_service.dart';
import 'package:moyun/core/services/insight_aggregation_service.dart';
import 'package:moyun/core/services/vision_analysis_gateway.dart';
import 'package:moyun/features/statistics/widgets/data_insight_card.dart';
import 'package:moyun/shared/constants.dart';

void main() {
  testWidgets('rerun failure clears previous insight result and shows error', (
    tester,
  ) async {
    final service = _SequenceDataInsightService(
      firstResult: const DataInsightResult(
        isStructured: true,
        model: 'fake-model',
        rawText: '{"summary":"summary-first"}',
        summary: 'summary-first',
        revenueInsight: 'revenue-first',
        engagementInsight: 'engagement-first',
        riskAlerts: ['risk-first'],
        recommendations: ['recommendation-first'],
      ),
      secondError: Exception('boom'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataInsightServiceProvider.overrideWithValue(service),
          statisticsNowProvider.overrideWith((ref) => DateTime(2026, 4, 3)),
          studentDaoProvider.overrideWithValue(
            _FakeStudentDao(const [
              StudentWithMeta(
                Student(
                  id: 'student-1',
                  name: 'Alice',
                  pricePerClass: 200,
                  status: 'active',
                  createdAt: 1,
                  updatedAt: 1,
                ),
                '2026-03-30',
              ),
            ]),
          ),
          attendanceDaoProvider.overrideWithValue(_FakeAttendanceDao()),
          paymentDaoProvider.overrideWithValue(_FakePaymentDao()),
          dismissedInsightDaoProvider.overrideWithValue(
            _FakeDismissedInsightDao(),
          ),
          insightServiceProvider.overrideWithValue(
            _FakeInsightAggregationService(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: DataInsightCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    final runButton = find.byType(FilledButton);
    expect(runButton, findsOneWidget);

    await tester.tap(runButton);
    await _settleUi(tester);

    expect(find.text('summary-first'), findsOneWidget);
    expect(find.text('revenue-first'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);

    await tester.tap(runButton);
    await _settleUi(tester);

    expect(find.text('summary-first'), findsNothing);
    expect(find.text('revenue-first'), findsNothing);
    expect(find.textContaining('Exception: boom'), findsOneWidget);
  });

  testWidgets('drops stale insight result after statistics period changes', (
    tester,
  ) async {
    final completer = Completer<DataInsightResult>();
    final container = ProviderContainer(
      overrides: [
        dataInsightServiceProvider.overrideWithValue(
          _CompleterDataInsightService(completer),
        ),
        statisticsNowProvider.overrideWith((ref) => DateTime(2026, 4, 3)),
        studentDaoProvider.overrideWithValue(
          _FakeStudentDao(const [
            StudentWithMeta(
              Student(
                id: 'student-1',
                name: 'Alice',
                pricePerClass: 200,
                status: 'active',
                createdAt: 1,
                updatedAt: 1,
              ),
              '2026-03-30',
            ),
          ]),
        ),
        attendanceDaoProvider.overrideWithValue(_FakeAttendanceDao()),
        paymentDaoProvider.overrideWithValue(_FakePaymentDao()),
        dismissedInsightDaoProvider.overrideWithValue(
          _FakeDismissedInsightDao(),
        ),
        insightServiceProvider.overrideWithValue(
          _FakeInsightAggregationService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: DataInsightCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    container.read(statisticsPeriodSelectionProvider.notifier).state =
        StatisticsPeriod.week;
    await tester.pump();

    completer.complete(
      const DataInsightResult(
        isStructured: true,
        model: 'fake-model',
        rawText: '{"summary":"stale-summary"}',
        summary: 'stale-summary',
        revenueInsight: 'stale-revenue',
        engagementInsight: 'stale-engagement',
        riskAlerts: ['stale-risk'],
        recommendations: ['stale-recommendation'],
      ),
    );
    await _settleUi(tester);

    expect(find.text('stale-summary'), findsNothing);
    expect(find.text('stale-revenue'), findsNothing);
  });

  testWidgets('uses one duplicate-name map for insight summary inputs', (
    tester,
  ) async {
    final service = _CaptureDataInsightService();
    final paymentDao = _FakePaymentDao();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataInsightServiceProvider.overrideWithValue(service),
          statisticsNowProvider.overrideWith((ref) => DateTime(2026, 4, 3)),
          studentDaoProvider.overrideWithValue(
            _FakeStudentDao(const [
              StudentWithMeta(
                Student(
                  id: 'student-1',
                  name: 'Alex',
                  parentName: 'Parent A',
                  pricePerClass: 200,
                  status: 'active',
                  createdAt: 1,
                  updatedAt: 1,
                ),
                '2026-03-30',
              ),
              StudentWithMeta(
                Student(
                  id: 'student-2',
                  name: 'Alex',
                  parentName: 'Parent B',
                  pricePerClass: 200,
                  status: 'active',
                  createdAt: 2,
                  updatedAt: 2,
                ),
                null,
              ),
            ]),
          ),
          attendanceDaoProvider.overrideWithValue(_FakeAttendanceDao()),
          paymentDaoProvider.overrideWithValue(paymentDao),
          dismissedInsightDaoProvider.overrideWithValue(
            _FakeDismissedInsightDao(),
          ),
          insightServiceProvider.overrideWithValue(
            _DisplayNameInsightAggregationService(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: DataInsightCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    await tester.tap(find.byType(FilledButton));
    await _settleUi(tester);

    final summary = service.lastSummary;

    expect(summary, isNotNull);
    expect(summary!.periodRevenue, 200);
    expect(paymentDao.totalByDateRangeCalls, 1);
    expect(summary.topContributors.single.name, 'Alex\uFF08Parent A\uFF09');
    expect(summary.riskStudentNames, ['Alex\uFF08Parent A\uFF09']);
    expect(
      summary.insightMessages.single,
      'Alex\uFF08Parent A\uFF09: \u9700\u5173\u6CE8',
    );
  });
}

class _SequenceDataInsightService extends DataInsightService {
  final DataInsightResult firstResult;
  final Object secondError;
  int _calls = 0;

  _SequenceDataInsightService({
    required this.firstResult,
    required this.secondError,
  }) : super(gateway: _NoopVisionGateway());

  @override
  Future<DataInsightResult> analyzeBusinessData(
    BusinessDataSummary summary, {
    double temperature = 0.2,
  }) async {
    _calls += 1;
    if (_calls == 1) return firstResult;
    throw secondError;
  }
}

class _CompleterDataInsightService extends DataInsightService {
  final Completer<DataInsightResult> completer;

  _CompleterDataInsightService(this.completer)
    : super(gateway: _NoopVisionGateway());

  @override
  Future<DataInsightResult> analyzeBusinessData(
    BusinessDataSummary summary, {
    double temperature = 0.2,
  }) {
    return completer.future;
  }
}

class _CaptureDataInsightService extends DataInsightService {
  BusinessDataSummary? lastSummary;

  _CaptureDataInsightService() : super(gateway: _NoopVisionGateway());

  @override
  Future<DataInsightResult> analyzeBusinessData(
    BusinessDataSummary summary, {
    double temperature = 0.2,
  }) async {
    lastSummary = summary;
    return const DataInsightResult(
      isStructured: true,
      model: 'fake-model',
      rawText: '{"summary":"ok"}',
      summary: 'ok',
      revenueInsight: '',
      engagementInsight: '',
      riskAlerts: [],
      recommendations: [],
    );
  }
}

class _NoopVisionGateway implements VisionAnalysisGateway {
  @override
  Future<VisionAnalysisResult> analyze(VisionAnalysisRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<VisionAnalysisResult> analyzeText(TextAnalysisRequest request) {
    throw UnimplementedError();
  }
}

class _FakeStudentDao extends StudentDao {
  final List<StudentWithMeta> students;

  _FakeStudentDao(this.students) : super(DatabaseHelper.instance);

  @override
  Future<List<StudentWithMeta>> getStudentsWithLastAttendance() async =>
      students;
}

class _FakeAttendanceDao extends AttendanceDao {
  _FakeAttendanceDao() : super(DatabaseHelper.instance);

  @override
  Future<Map<String, dynamic>> getMetrics(String from, String to) async {
    return const {
      'totalFee': 200,
      'presentCount': 1,
      'lateCount': 0,
      'absentCount': 0,
      'activeStudentCount': 1,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getStudentContribution(
    String from,
    String to,
  ) async {
    return const [
      {'studentId': 'student-1', 'attendanceCount': 1},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getStatusDistribution(
    String from,
    String to,
  ) async {
    return const [
      {'status': 'present', 'count': 1},
    ];
  }

  @override
  Future<List<Attendance>> getByDateRange(String from, String to) async {
    return [
      Attendance(
        id: 'attendance-1',
        studentId: 'student-1',
        date: '2026-03-30',
        startTime: '10:00',
        endTime: '11:00',
        status: 'present',
        priceSnapshot: 200,
        feeAmount: 200,
        createdAt: 1,
        updatedAt: 1,
      ),
    ];
  }

  @override
  Future<Map<String, List<Attendance>>> getAllGroupedByStudent() async {
    return {
      'student-1': [
        Attendance(
          id: 'attendance-0',
          studentId: 'student-1',
          date: '2026-02-14',
          startTime: '10:00',
          endTime: '11:00',
          status: 'present',
          priceSnapshot: 200,
          feeAmount: 200,
          createdAt: 0,
          updatedAt: 0,
        ),
      ],
    };
  }
}

class _FakePaymentDao extends PaymentDao {
  int totalByDateRangeCalls = 0;

  _FakePaymentDao() : super(DatabaseHelper.instance);

  @override
  Future<double> getTotalByDateRange(String? from, String? to) async {
    totalByDateRangeCalls += 1;
    return 200;
  }

  @override
  Future<Map<String, double>> getTotalByAllStudentsAndDateRange(
    String? from,
    String? to,
  ) async {
    return const {'student-1': 200};
  }

  @override
  Future<Map<String, double>> getTotalByAllStudents() async {
    return const {'student-1': 200};
  }
}

class _FakeDismissedInsightDao extends DismissedInsightDao {
  _FakeDismissedInsightDao() : super(DatabaseHelper.instance);

  @override
  Future<Set<String>> getAllActiveKeys({DateTime? now}) async => const {};
}

class _FakeInsightAggregationService extends InsightAggregationService {
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
    return const [];
  }
}

class _DisplayNameInsightAggregationService extends InsightAggregationService {
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
    return [
      Insight(
        type: InsightType.renewal,
        studentId: 'student-1',
        studentName: displayNames['student-1'] ?? 'student-1',
        message: '\u9700\u5173\u6CE8',
        suggestion: '',
        calcLogic: '',
        dataFreshness: '',
      ),
    ];
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
