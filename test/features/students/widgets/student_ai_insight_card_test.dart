import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/models/student_insight_result.dart';
import 'package:moyun/core/providers/ai_provider.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/services/ai_analysis_note_codec.dart';
import 'package:moyun/core/services/student_insight_analysis_service.dart';
import 'package:moyun/core/services/vision_analysis_gateway.dart';
import 'package:moyun/features/students/widgets/student_ai_insight_card.dart';

void main() {
  testWidgets(
    'analyzes student insight and saves structured note back to student',
    (tester) async {
      final student = Student(
        id: 'student-1',
        name: 'Alice',
        pricePerClass: 200,
        status: 'active',
        note: AiAnalysisNoteCodec.appendHandwritingAnalysis(
          existingNote: null,
          analysisText: '课堂日期：2026-03-31 18:00-19:30\n总体概览：结构更稳',
          analyzedAt: DateTime(2026, 3, 31, 20, 0),
        ),
        createdAt: 1,
        updatedAt: 1,
      );
      final studentDao = _FakeStudentDao(student);
      final attendanceDao = _FakeAttendanceDao([
        Attendance(
          id: 'attendance-1',
          studentId: student.id,
          date: '2026-03-31',
          startTime: '18:00',
          endTime: '19:30',
          status: 'present',
          priceSnapshot: 200,
          feeAmount: 200,
          createdAt: 1,
          updatedAt: 1,
        ),
      ]);
      final service = _FakeStudentInsightAnalysisService(
        const StudentInsightResult(
          isStructured: true,
          model: 'fake-model',
          rawText: '{"summary":"SENTINEL_SUMMARY"}',
          summary: 'SENTINEL_SUMMARY',
          attendancePattern: 'SENTINEL_PATTERN',
          writingObservation: 'SENTINEL_WRITING',
          progressInsight: 'SENTINEL_PROGRESS',
          riskAlerts: ['SENTINEL_RISK'],
          teachingSuggestions: ['SENTINEL_ACTION'],
          parentCommunicationTip: 'SENTINEL_PARENT',
        ),
      );
      _FakeStudentNotifier.seededStudents = [
        StudentWithMeta(student, '2026-03-31'),
      ];
      _FakeStudentNotifier.reloadCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentInsightAnalysisServiceProvider.overrideWithValue(service),
            attendanceDaoProvider.overrideWithValue(attendanceDao),
            studentDaoProvider.overrideWithValue(studentDao),
            studentProvider.overrideWith(_FakeStudentNotifier.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: StudentAiInsightCard(student: student),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settleUi(tester);

      expect(find.text('作品分析 1 条'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await _settleUi(tester);

      expect(find.text('SENTINEL_SUMMARY'), findsOneWidget);
      expect(find.textContaining('SENTINEL_ACTION'), findsOneWidget);

      final saveButton = find.byType(ElevatedButton);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await _settleUi(tester);

      expect(studentDao.updatedStudent, isNotNull);
      expect(
        AiAnalysisNoteCodec.latestContent(
          studentDao.updatedStudent!.note,
          type: 'student_insight',
        ),
        contains('SENTINEL_SUMMARY'),
      );
      expect(_FakeStudentNotifier.reloadCount, 1);
    },
  );
}

class _FakeStudentInsightAnalysisService extends StudentInsightAnalysisService {
  final StudentInsightResult result;

  _FakeStudentInsightAnalysisService(this.result)
    : super(gateway: _NoopVisionGateway());

  @override
  Future<StudentInsightResult> analyzeStudentInsight(
    Student student,
    List<Attendance> attendanceRecords, {
    double temperature = 0.2,
    DateTime? now,
  }) async {
    return result;
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

class _FakeAttendanceDao extends AttendanceDao {
  final List<Attendance> records;

  _FakeAttendanceDao(this.records) : super(DatabaseHelper.instance);

  @override
  Future<List<Attendance>> getByStudentPaged(
    String studentId,
    int limit,
    int offset,
  ) async {
    return records;
  }
}

class _FakeStudentDao extends StudentDao {
  Student currentStudent;
  Student? updatedStudent;

  _FakeStudentDao(this.currentStudent) : super(DatabaseHelper.instance);

  @override
  Future<Student?> getById(String id) async => currentStudent;

  @override
  Future<void> update(Student s) async {
    updatedStudent = s;
    currentStudent = s;
  }
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];
  static int reloadCount = 0;

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;

  @override
  Future<void> reload() async {
    reloadCount += 1;
    state = AsyncData(seededStudents);
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
