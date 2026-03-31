import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/services/ai_analysis_note_codec.dart';
import 'package:moyun/features/export/screens/export_config_screen.dart';

void main() {
  testWidgets('shows saved AI analysis hint after enabling include toggle', (
    tester,
  ) async {
    final note = AiAnalysisNoteCodec.appendProgressAnalysis(
      existingNote: null,
      analysisText: 'SENTINEL_EXPORT_ANALYSIS',
      analyzedAt: DateTime(2026, 4, 1, 9),
    );
    final student = Student(
      id: 'student-1',
      name: 'Alice',
      pricePerClass: 200,
      status: 'active',
      note: note,
      createdAt: 1,
      updatedAt: 1,
    );

    await _pumpScreen(tester, student);

    expect(
      find.text(
        '\u5173\u95ed\u540e\uff0cPDF \u4e0d\u4f1a\u5305\u542b AI \u5206\u6790\u9875\u3002',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byType(Switch).last);
    await tester.tap(find.byType(Switch).last);
    await _settleUi(tester);

    expect(
      find.text(
        '\u4f1a\u4ece\u5b66\u751f\u5907\u6ce8\u4e2d\u63d0\u53d6\u5df2\u4fdd\u5b58\u7684 AI \u5206\u6790\uff0c\u5e76\u63d2\u5165 PDF\u3002',
      ),
      findsOneWidget,
    );
  });

  testWidgets('disables AI analysis toggle when note has no saved analysis', (
    tester,
  ) async {
    const student = Student(
      id: 'student-2',
      name: 'Bob',
      pricePerClass: 180,
      status: 'active',
      note: 'manual note only',
      createdAt: 1,
      updatedAt: 1,
    );

    await _pumpScreen(tester, student);

    expect(
      find.text(
        '\u6682\u65e0\u5df2\u4fdd\u5b58\u7684 AI \u5206\u6790\uff0c\u8bf7\u5148\u5728\u5b66\u751f\u8be6\u60c5\u9875\u4fdd\u5b58\u5206\u6790\u7ed3\u679c\u3002',
      ),
      findsOneWidget,
    );

    final aiSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(aiSwitch.onChanged, isNull);
  });
}

Future<void> _pumpScreen(WidgetTester tester, Student student) async {
  _FakeSettingsNotifier.seededSettings = const {
    'default_message_template': '',
    'default_watermark_enabled': 'true',
  };
  _FakeStudentNotifier.seededStudents = [StudentWithMeta(student, null)];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        studentDaoProvider.overrideWithValue(_FakeStudentDao(student)),
        studentProvider.overrideWith(_FakeStudentNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ExportConfigScreen(studentId: student.id),
        ),
      ),
    ),
  );
  await _settleUi(tester);
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {};

  @override
  Future<Map<String, String>> build() async => seededSettings;
}

class _FakeStudentDao extends StudentDao {
  final Student student;

  _FakeStudentDao(this.student) : super(DatabaseHelper.instance);

  @override
  Future<Student?> getById(String id) async {
    if (id != student.id) return null;
    return student;
  }
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
