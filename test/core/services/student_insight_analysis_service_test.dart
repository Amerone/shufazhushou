import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/services/ai_analysis_note_codec.dart';
import 'package:moyun/core/services/student_insight_analysis_service.dart';
import 'package:moyun/core/services/vision_analysis_gateway.dart';

void main() {
  group('StudentInsightAnalysisService', () {
    test(
      'builds prompt from attendance, handwriting and saved progress data',
      () async {
        final student = Student(
          id: 'student-1',
          name: 'Alice',
          pricePerClass: 200,
          status: 'active',
          note: AiAnalysisNoteCodec.appendProgressAnalysis(
            existingNote: AiAnalysisNoteCodec.appendHandwritingAnalysis(
              existingNote: null,
              analysisText:
                  '课堂日期：2026-03-30 10:00-11:00\n总体概览：结构更稳定\n笔画观察：起收更干净',
              analyzedAt: DateTime(2026, 3, 30, 12, 0),
            ),
            analysisText: '总体评价：最近结构更稳，节奏还要再拉开。',
            analyzedAt: DateTime(2026, 3, 31, 12, 0),
          ),
          createdAt: 1,
          updatedAt: 1,
        );
        final records = [
          Attendance(
            id: 'attendance-1',
            studentId: student.id,
            date: '2026-03-24',
            startTime: '18:00',
            endTime: '19:30',
            status: 'present',
            priceSnapshot: 200,
            feeAmount: 200,
            lessonFocusTags: const ['结构', '控笔'],
            homePracticeNote: '每天临摹 15 分钟',
            progressScores: const AttendanceProgressScores(
              strokeQuality: 3.6,
              structureAccuracy: 3.8,
              rhythmConsistency: 3.5,
            ),
            createdAt: 1,
            updatedAt: 1,
          ),
          Attendance(
            id: 'attendance-2',
            studentId: student.id,
            date: '2026-03-30',
            startTime: '18:00',
            endTime: '19:30',
            status: 'late',
            priceSnapshot: 200,
            feeAmount: 200,
            lessonFocusTags: const ['结构', '行气连贯'],
            homePracticeNote: '观察字距和重心',
            progressScores: const AttendanceProgressScores(
              strokeQuality: 4.0,
              structureAccuracy: 4.2,
              rhythmConsistency: 3.9,
            ),
            createdAt: 2,
            updatedAt: 2,
          ),
        ];
        final gateway = _CapturingGateway(
          responseText:
              '{"summary":"SENTINEL_SUMMARY","attendance_pattern":"SENTINEL_PATTERN","writing_observation":"SENTINEL_WRITING","progress_insight":"SENTINEL_PROGRESS","risk_alerts":["SENTINEL_RISK"],"teaching_suggestions":["SENTINEL_ACTION"],"parent_communication_tip":"SENTINEL_PARENT"}',
        );
        final service = StudentInsightAnalysisService(gateway: gateway);

        final result = await service.analyzeStudentInsight(
          student,
          records,
          now: DateTime(2026, 4, 1),
        );
        final prompt = gateway.lastTextRequest!.prompt;

        expect(result.summary, 'SENTINEL_SUMMARY');
        expect(result.attendancePattern, 'SENTINEL_PATTERN');
        expect(result.writingObservation, 'SENTINEL_WRITING');
        expect(prompt, contains('Alice'));
        expect(prompt, contains('最近保存的课堂作品分析'));
        expect(prompt, contains('结构更稳定'));
        expect(prompt, contains('最近保存的 AI 学习分析'));
        expect(prompt, contains('最近结构更稳'));
        expect(prompt, contains('常见上课时段'));
        expect(prompt, contains('"parent_communication_tip"'));
      },
    );

    test('throws when there is no attendance or handwriting data', () async {
      final service = StudentInsightAnalysisService(
        gateway: _CapturingGateway(responseText: '{}'),
      );
      final student = Student(
        id: 'student-empty',
        name: 'Nobody',
        pricePerClass: 180,
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
      );

      await expectLater(
        () => service.analyzeStudentInsight(student, const []),
        throwsA(isA<VisionAnalysisException>()),
      );
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
