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

    container.read(statisticsPeriodProvider.notifier).state =
        buildStatisticsRange(StatisticsPeriod.week);
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
  _FakePaymentDao() : super(DatabaseHelper.instance);

  @override
  Future<double> getTotalByDateRange(String? from, String? to) async => 200;

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

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
