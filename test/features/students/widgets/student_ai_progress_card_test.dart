import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/progress_analysis_result.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/ai_provider.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/services/ai_analysis_note_codec.dart';
import 'package:moyun/core/services/progress_analysis_service.dart';
import 'package:moyun/core/services/vision_analysis_gateway.dart';
import 'package:moyun/features/students/widgets/student_ai_progress_card.dart';

void main() {
  testWidgets('analyzes progress and saves structured note back to student', (
    tester,
  ) async {
    const student = Student(
      id: 'student-1',
      name: 'Alice',
      pricePerClass: 200,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    );
    final studentDao = _FakeStudentDao(student);
    final attendanceDao = _FakeAttendanceDao([
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
    ]);
    final service = _FakeProgressAnalysisService(
      const ProgressAnalysisResult(
        isStructured: true,
        model: 'fake-model',
        rawText: '{"overall_assessment":"SENTINEL_OVERALL"}',
        overallAssessment: 'SENTINEL_OVERALL',
        trendAnalysis: 'SENTINEL_TREND',
        strengths: 'SENTINEL_STRENGTH',
        areasToImprove: 'SENTINEL_IMPROVE',
        teachingSuggestions: ['SENTINEL_SUGGESTION'],
      ),
    );
    _FakeStudentNotifier.seededStudents = [
      const StudentWithMeta(student, '2026-03-30'),
    ];
    _FakeStudentNotifier.reloadCount = 0;
    var savedCallbackCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressAnalysisServiceProvider.overrideWithValue(service),
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
                  child: StudentAiProgressCard(
                    student: student,
                    onSaved: () => savedCallbackCount += 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    final analyzeButton = find.byType(OutlinedButton);
    expect(analyzeButton, findsOneWidget);

    await tester.tap(analyzeButton);
    await _settleUi(tester);

    expect(find.text('SENTINEL_OVERALL'), findsOneWidget);
    expect(find.textContaining('SENTINEL_SUGGESTION'), findsOneWidget);

    final saveButton = find.byType(ElevatedButton);
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await _settleUi(tester);

    expect(studentDao.updatedStudent, isNotNull);
    final savedNote = studentDao.updatedStudent!.note;
    expect(
      AiAnalysisNoteCodec.latestContent(savedNote, type: 'progress'),
      contains('SENTINEL_OVERALL'),
    );
    expect(_FakeStudentNotifier.reloadCount, 1);
    expect(savedCallbackCount, 1);
  });

  testWidgets('shows saved progress analysis immediately on first render', (
    tester,
  ) async {
    final savedNote = AiAnalysisNoteCodec.appendProgressAnalysis(
      existingNote: null,
      analysisText:
          '总体评价：最近整体更稳\n'
          '趋势分析：结构和节奏都在提升\n'
          '优势方面：起收笔更干净\n'
          '需加强方面：章法还要再拉开一些\n'
          '教学建议：\n'
          '1. 继续做控笔热身\n'
          '2. 临摹时多看重心位置',
      analyzedAt: DateTime(2026, 3, 31, 10, 0),
    );
    final student = Student(
      id: 'student-saved',
      name: 'Daisy',
      pricePerClass: 200,
      status: 'active',
      note: savedNote,
      createdAt: 1,
      updatedAt: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressAnalysisServiceProvider.overrideWithValue(
            _FakeProgressAnalysisService(
              const ProgressAnalysisResult(
                isStructured: true,
                model: 'fake-model',
                rawText: '{"overall_assessment":"unused"}',
                overallAssessment: 'unused',
                trendAnalysis: '',
                strengths: '',
                areasToImprove: '',
                teachingSuggestions: [],
              ),
            ),
          ),
          attendanceDaoProvider.overrideWithValue(_FakeAttendanceDao(const [])),
          studentDaoProvider.overrideWithValue(_FakeStudentDao(student)),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StudentAiProgressCard(student: student),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.text('最近整体更稳'), findsOneWidget);
    expect(find.text('结构和节奏都在提升'), findsOneWidget);
    expect(find.text('起收笔更干净'), findsOneWidget);
    expect(find.text('已保存'), findsOneWidget);
    expect(find.text('更新近期学习进展'), findsOneWidget);
    expect(find.text('生成时间：2026-03-31 10:00'), findsOneWidget);
  });

  testWidgets('rerun failure clears previous progress result and shows error', (
    tester,
  ) async {
    const student = Student(
      id: 'student-2',
      name: 'Bob',
      pricePerClass: 180,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    );
    final attendanceDao = _FakeAttendanceDao([
      Attendance(
        id: 'attendance-2',
        studentId: 'student-2',
        date: '2026-03-31',
        startTime: '09:00',
        endTime: '10:00',
        status: 'present',
        priceSnapshot: 180,
        feeAmount: 180,
        createdAt: 1,
        updatedAt: 1,
      ),
    ]);
    final service = _SequenceProgressAnalysisService(
      firstResult: const ProgressAnalysisResult(
        isStructured: true,
        model: 'fake-model',
        rawText: '{"overall_assessment":"SENTINEL_PROGRESS_OK"}',
        overallAssessment: 'SENTINEL_PROGRESS_OK',
        trendAnalysis: '',
        strengths: '',
        areasToImprove: '',
        teachingSuggestions: [],
      ),
      secondError: const VisionAnalysisException('mock-fail'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressAnalysisServiceProvider.overrideWithValue(service),
          attendanceDaoProvider.overrideWithValue(attendanceDao),
          studentDaoProvider.overrideWithValue(_FakeStudentDao(student)),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StudentAiProgressCard(student: student),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    final analyzeButton = find.byType(OutlinedButton);
    await tester.tap(analyzeButton);
    await _settleUi(tester);

    expect(find.text('SENTINEL_PROGRESS_OK'), findsOneWidget);
    expect(find.textContaining('mock-fail'), findsNothing);

    await tester.tap(analyzeButton);
    await _settleUi(tester);

    expect(find.text('SENTINEL_PROGRESS_OK'), findsNothing);
    expect(find.textContaining('mock-fail'), findsOneWidget);
  });

  testWidgets(
    'does not append duplicate progress note when current analysis already exists',
    (tester) async {
      final existingNote = AiAnalysisNoteCodec.appendProgressAnalysis(
        existingNote: null,
        analysisText:
            '总体评价：SENTINEL_OVERALL\n'
            '趋势分析：SENTINEL_TREND\n'
            '优势方面：SENTINEL_STRENGTH\n'
            '需加强方面：SENTINEL_IMPROVE\n'
            '教学建议：\n'
            '1. SENTINEL_SUGGESTION',
        analyzedAt: DateTime(2026, 3, 31, 10, 0),
      );
      final student = Student(
        id: 'student-3',
        name: 'Carol',
        pricePerClass: 220,
        status: 'active',
        note: existingNote,
        createdAt: 1,
        updatedAt: 1,
      );
      final studentDao = _FakeStudentDao(student);
      final attendanceDao = _FakeAttendanceDao([
        Attendance(
          id: 'attendance-3',
          studentId: 'student-3',
          date: '2026-03-31',
          startTime: '08:00',
          endTime: '09:00',
          status: 'present',
          priceSnapshot: 220,
          feeAmount: 220,
          createdAt: 1,
          updatedAt: 1,
        ),
      ]);
      final service = _FakeProgressAnalysisService(
        const ProgressAnalysisResult(
          isStructured: true,
          model: 'fake-model',
          rawText: '{"overall_assessment":"SENTINEL_OVERALL"}',
          overallAssessment: 'SENTINEL_OVERALL',
          trendAnalysis: 'SENTINEL_TREND',
          strengths: 'SENTINEL_STRENGTH',
          areasToImprove: 'SENTINEL_IMPROVE',
          teachingSuggestions: ['SENTINEL_SUGGESTION'],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressAnalysisServiceProvider.overrideWithValue(service),
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
                    child: StudentAiProgressCard(student: student),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settleUi(tester);

      await tester.tap(find.byType(OutlinedButton));
      await _settleUi(tester);

      final saveButton = find.byType(ElevatedButton);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await _settleUi(tester);

      expect(studentDao.updateCount, 0);
      expect(find.text('已保存到学生备注'), findsOneWidget);
    },
  );

  testWidgets(
    'preserves unsaved analysis when widget rebuilds with refreshed note',
    (tester) async {
      final initialStudent = Student(
        id: 'student-4',
        name: 'Eve',
        pricePerClass: 180,
        status: 'active',
        note: AiAnalysisNoteCodec.appendProgressAnalysis(
          existingNote: null,
          analysisText: '总体评价：旧分析\n趋势分析：旧趋势',
          analyzedAt: DateTime(2026, 3, 28, 10, 0),
        ),
        createdAt: 1,
        updatedAt: 1,
      );
      final hostKey = GlobalKey<_ProgressHostState>();
      final attendanceDao = _FakeAttendanceDao([
        Attendance(
          id: 'attendance-4',
          studentId: 'student-4',
          date: '2026-03-31',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 180,
          feeAmount: 180,
          createdAt: 1,
          updatedAt: 1,
        ),
      ]);
      final service = _FakeProgressAnalysisService(
        const ProgressAnalysisResult(
          isStructured: true,
          model: 'fake-model',
          rawText: '{"overall_assessment":"SENTINEL_NEW"}',
          overallAssessment: 'SENTINEL_NEW',
          trendAnalysis: 'SENTINEL_TREND_NEW',
          strengths: '',
          areasToImprove: '',
          teachingSuggestions: [],
        ),
      );
      final studentDao = _FakeStudentDao(initialStudent);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressAnalysisServiceProvider.overrideWithValue(service),
            attendanceDaoProvider.overrideWithValue(attendanceDao),
            studentDaoProvider.overrideWithValue(studentDao),
            studentProvider.overrideWith(_FakeStudentNotifier.new),
          ],
          child: MaterialApp(
            home: _ProgressHost(key: hostKey, student: initialStudent),
          ),
        ),
      );
      await _settleUi(tester);

      await tester.tap(find.byType(OutlinedButton));
      await _settleUi(tester);
      expect(find.text('SENTINEL_NEW'), findsOneWidget);

      hostKey.currentState!.updateStudent(
        initialStudent.copyWith(
          note: AiAnalysisNoteCodec.appendProgressAnalysis(
            existingNote: null,
            analysisText: '总体评价：外部刷新\n趋势分析：外部刷新趋势',
            analyzedAt: DateTime(2026, 4, 1, 10, 0),
          ),
        ),
      );
      await _settleUi(tester);

      expect(find.text('SENTINEL_NEW'), findsOneWidget);
      expect(find.text('外部刷新'), findsNothing);
    },
  );

  testWidgets(
    'clears previous analysis when switching to another student with no saved note',
    (tester) async {
      const firstStudent = Student(
        id: 'student-5',
        name: 'Faye',
        pricePerClass: 180,
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
      );
      const secondStudent = Student(
        id: 'student-6',
        name: 'Gina',
        pricePerClass: 200,
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
      );
      final hostKey = GlobalKey<_ProgressHostState>();
      final attendanceDao = _FakeAttendanceDao([
        Attendance(
          id: 'attendance-5',
          studentId: 'student-5',
          date: '2026-03-31',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 180,
          feeAmount: 180,
          createdAt: 1,
          updatedAt: 1,
        ),
      ]);
      final service = _FakeProgressAnalysisService(
        const ProgressAnalysisResult(
          isStructured: true,
          model: 'fake-model',
          rawText: '{"overall_assessment":"SENTINEL_SWITCH"}',
          overallAssessment: 'SENTINEL_SWITCH',
          trendAnalysis: '',
          strengths: '',
          areasToImprove: '',
          teachingSuggestions: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressAnalysisServiceProvider.overrideWithValue(service),
            attendanceDaoProvider.overrideWithValue(attendanceDao),
            studentDaoProvider.overrideWithValue(_FakeStudentDao(firstStudent)),
            studentProvider.overrideWith(_FakeStudentNotifier.new),
          ],
          child: MaterialApp(
            home: _ProgressHost(key: hostKey, student: firstStudent),
          ),
        ),
      );
      await _settleUi(tester);

      await tester.tap(find.byType(OutlinedButton));
      await _settleUi(tester);
      expect(find.text('SENTINEL_SWITCH'), findsOneWidget);

      hostKey.currentState!.updateStudent(secondStudent);
      await _settleUi(tester);

      expect(find.text('SENTINEL_SWITCH'), findsNothing);
      expect(find.text('待生成'), findsOneWidget);
    },
  );
}

class _FakeProgressAnalysisService extends ProgressAnalysisService {
  final ProgressAnalysisResult result;

  _FakeProgressAnalysisService(this.result)
    : super(gateway: _NoopVisionGateway());

  @override
  Future<ProgressAnalysisResult> analyzeStudentProgress(
    Student student,
    List<Attendance> attendanceRecords, {
    double temperature = 0.2,
  }) async {
    return result;
  }
}

class _SequenceProgressAnalysisService extends ProgressAnalysisService {
  final ProgressAnalysisResult firstResult;
  final Object secondError;
  int _calls = 0;

  _SequenceProgressAnalysisService({
    required this.firstResult,
    required this.secondError,
  }) : super(gateway: _NoopVisionGateway());

  @override
  Future<ProgressAnalysisResult> analyzeStudentProgress(
    Student student,
    List<Attendance> attendanceRecords, {
    double temperature = 0.2,
  }) async {
    _calls += 1;
    if (_calls == 1) return firstResult;
    throw secondError;
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
  int updateCount = 0;

  _FakeStudentDao(this.currentStudent) : super(DatabaseHelper.instance);

  @override
  Future<Student?> getById(String id) async => currentStudent;

  @override
  Future<void> update(Student s) async {
    updateCount += 1;
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

class _ProgressHost extends StatefulWidget {
  final Student student;

  const _ProgressHost({super.key, required this.student});

  @override
  State<_ProgressHost> createState() => _ProgressHostState();
}

class _ProgressHostState extends State<_ProgressHost> {
  late Student _student;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
  }

  void updateStudent(Student student) {
    setState(() => _student = student);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StudentAiProgressCard(student: _student),
          ),
        ),
      ),
    );
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
