import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/business_data_summary.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/services/data_insight_service.dart';
import 'package:moyun/core/services/progress_analysis_service.dart';
import 'package:moyun/core/services/vision_analysis_gateway.dart';

void main() {
  group('ProgressAnalysisService', () {
    test(
      'analyzeStudentProgress uses recent ten records in ascending order',
      () async {
        final gateway = _CapturingGateway(
          responseText:
              '{"overall_assessment":"ok","trend_analysis":"","strengths":"","areas_to_improve":"","teaching_suggestions":[]}',
        );
        final service = ProgressAnalysisService(gateway: gateway);
        final student = Student(
          id: 'student-1',
          name: 'Alice',
          pricePerClass: 200,
          status: 'active',
          createdAt: 0,
          updatedAt: 0,
        );
        final records = List.generate(12, (index) {
          final day = (index + 1).toString().padLeft(2, '0');
          return Attendance(
            id: 'a$index',
            studentId: student.id,
            date: '2026-03-$day',
            startTime: '10:00',
            endTime: '11:00',
            status: 'present',
            priceSnapshot: 200,
            feeAmount: 200,
            lessonFocusTags: const ['stroke'],
            homePracticeNote: 'practice',
            progressScores: const AttendanceProgressScores(
              strokeQuality: 4,
              structureAccuracy: 4.5,
              rhythmConsistency: 5,
            ),
            createdAt: index,
            updatedAt: index,
          );
        });

        final result = await service.analyzeStudentProgress(student, records);
        final prompt = gateway.lastTextRequest!.prompt;

        expect(result.overallAssessment, 'ok');
        expect(prompt, contains('Alice'));
        expect(prompt, isNot(contains('2026-03-01')));
        expect(prompt, isNot(contains('2026-03-02')));
        expect(prompt, contains('2026-03-03'));
        expect(prompt, contains('2026-03-12'));
        expect(
          prompt.indexOf('2026-03-03'),
          lessThan(prompt.indexOf('2026-03-12')),
        );
        expect(prompt, contains('"overall_assessment"'));
        expect(prompt, contains('"teaching_suggestions"'));
      },
    );

    test(
      'analyzeStudentProgress throws when no attendance records are available',
      () async {
        final gateway = _CapturingGateway(responseText: '{}');
        final service = ProgressAnalysisService(gateway: gateway);
        final student = Student(
          id: 'student-empty',
          name: 'Alice',
          pricePerClass: 200,
          status: 'active',
          createdAt: 0,
          updatedAt: 0,
        );

        await expectLater(
          () => service.analyzeStudentProgress(student, const []),
          throwsA(isA<VisionAnalysisException>()),
        );
        expect(gateway.lastTextRequest, isNull);
      },
    );
  });

  group('DataInsightService', () {
    test('analyzeBusinessData builds prompt from typed summary', () async {
      final gateway = _CapturingGateway(
        responseText:
            '{"summary":"healthy","revenue_insight":"steady","engagement_insight":"good","risk_alerts":["watch Bob"],"recommendations":["follow up"]}',
      );
      final service = DataInsightService(gateway: gateway);

      const summary = BusinessDataSummary(
        periodLabel: '2026-03-01 to 2026-03-31',
        activeStudentCount: 18,
        inactiveStudentCount: 4,
        periodRevenue: 8800,
        attendanceStatusDistribution: {'present': 42, 'late': 3, 'absent': 2},
        topContributors: [
          BusinessContributorSnapshot(
            name: 'Alice',
            totalFee: 2400,
            attendanceCount: 12,
          ),
        ],
        riskStudentNames: ['Bob'],
        insightMessages: ['Bob: 7 days inactive'],
      );

      final result = await service.analyzeBusinessData(summary);
      final prompt = gateway.lastTextRequest!.prompt;

      expect(result.summary, 'healthy');
      expect(prompt, contains('2026-03-01 to 2026-03-31'));
      expect(prompt, contains('Alice'));
      expect(prompt, contains('2400.00'));
      expect(prompt, contains('12'));
      expect(prompt, contains('Bob: 7 days inactive'));
      expect(prompt, contains('"risk_alerts"'));
      expect(prompt, contains('"recommendations"'));
    });
  });
}

class _CapturingGateway implements VisionAnalysisGateway {
  final String responseText;
  TextAnalysisRequest? lastTextRequest;

  _CapturingGateway({required this.responseText});

  @override
  Future<VisionAnalysisResult> analyze(VisionAnalysisRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<VisionAnalysisResult> analyzeText(TextAnalysisRequest request) async {
    lastTextRequest = request;
    return VisionAnalysisResult(
      model: 'fake-model',
      text: responseText,
      raw: const {},
    );
  }
}
