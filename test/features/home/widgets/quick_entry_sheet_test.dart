import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/class_template.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/class_template_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/home/widgets/quick_entry_sheet.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  setUp(() {
    _FakeSettingsNotifier.seededSettings = const {
      InteractionFeedback.hapticsEnabledKey: 'false',
      InteractionFeedback.soundEnabledKey: 'false',
      'quick_entry_default_start_time': '18:00',
      'quick_entry_default_end_time': '19:30',
      'quick_entry_default_status': 'late',
      'quick_entry_recent_student_ids': 'student-1,student-2',
    };
    _FakeStudentNotifier.seededStudents = _seededStudents;
  });

  testWidgets('restores recent student group and remembered defaults', (
    tester,
  ) async {
    _setLargeViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
          classTemplateProvider.overrideWith(_FakeClassTemplateNotifier.new),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: QuickEntrySheet()),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.text('恢复上次同班（2人）'), findsOneWidget);
    expect(find.textContaining('当前默认：18:00-19:30 / 迟到'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, '恢复上次同班（2人）'));
    await _settleUi(tester);

    expect(find.text('已选 2'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '直接保存（2人 / ¥380）'), findsOneWidget);
  });

  testWidgets('preserves existing feedback and artwork on conflict overwrite', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final existingRecord = Attendance(
      id: 'attendance-old',
      studentId: 'student-1',
      date: '2026-04-17',
      startTime: '18:00',
      endTime: '19:30',
      status: 'present',
      priceSnapshot: 180,
      feeAmount: 180,
      note: 'manual note',
      lessonFocusTags: const ['章法布局'],
      homePracticeNote: 'old practice',
      progressScores: const AttendanceProgressScores(strokeQuality: 4),
      artworkImagePath: 'artworks/old.png',
      createdAt: 11,
      updatedAt: 22,
    );
    final fakeDao = _FakeAttendanceDao({'student-1': existingRecord});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
          classTemplateProvider.overrideWith(_FakeClassTemplateNotifier.new),
          attendanceDaoProvider.overrideWithValue(fakeDao),
          selectedDateProvider.overrideWith((ref) => DateTime(2026, 4, 17)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: QuickEntrySheet(initialSelectedIds: {'student-1'}),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    await tester.tap(find.textContaining('下一步'));
    await _settleUi(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '确认保存'));
    await _settleUi(tester);

    await tester.tap(find.widgetWithText(TextButton, '确认'));
    await _settleUi(tester);

    expect(fakeDao.savedConflictIds, {'student-1': 'attendance-old'});
    expect(fakeDao.savedRecords, hasLength(1));

    final savedRecord = fakeDao.savedRecords.single;
    expect(savedRecord.id, existingRecord.id);
    expect(savedRecord.note, existingRecord.note);
    expect(savedRecord.lessonFocusTags, existingRecord.lessonFocusTags);
    expect(savedRecord.homePracticeNote, existingRecord.homePracticeNote);
    expect(savedRecord.progressScores, existingRecord.progressScores);
    expect(savedRecord.artworkImagePath, existingRecord.artworkImagePath);
    expect(savedRecord.createdAt, existingRecord.createdAt);
    expect(savedRecord.date, '2026-04-17');
    expect(savedRecord.startTime, '18:00');
    expect(savedRecord.endTime, '19:30');
    expect(savedRecord.status, 'late');
    expect(savedRecord.priceSnapshot, 180);
    expect(savedRecord.feeAmount, 180);
    expect(savedRecord.updatedAt, greaterThan(existingRecord.updatedAt));
  });
}

final _seededStudents = [
  StudentWithMeta(
    const Student(
      id: 'student-1',
      name: 'Alice',
      parentName: 'Parent A',
      parentPhone: '13900000001',
      pricePerClass: 180,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    ),
    null,
  ),
  StudentWithMeta(
    const Student(
      id: 'student-2',
      name: 'Bob',
      parentName: 'Parent B',
      parentPhone: '13900000002',
      pricePerClass: 200,
      status: 'active',
      createdAt: 2,
      updatedAt: 2,
    ),
    null,
  ),
];

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {};

  @override
  Future<Map<String, String>> build() async => seededSettings;

  @override
  Future<void> setAll(Map<String, String> entries) async {
    seededSettings = {...seededSettings, ...entries};
    state = AsyncData(seededSettings);
  }
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;
}

class _FakeClassTemplateNotifier extends ClassTemplateNotifier {
  @override
  Future<List<ClassTemplate>> build() async => const [];
}

class _FakeAttendanceDao extends AttendanceDao {
  final Map<String, Attendance> conflictsByStudentId;
  List<Attendance> savedRecords = const [];
  Map<String, String> savedConflictIds = const {};

  _FakeAttendanceDao(this.conflictsByStudentId)
    : super(DatabaseHelper.instance);

  @override
  Future<Map<String, Attendance>> findConflictsForStudents(
    Iterable<String> studentIds,
    String date,
    String startTime,
    String endTime, {
    String? excludeId,
  }) async {
    final ids = studentIds.toSet();
    return {
      for (final entry in conflictsByStudentId.entries)
        if (ids.contains(entry.key)) entry.key: entry.value,
    };
  }

  @override
  Future<void> batchInsertWithConflictReplace(
    List<Attendance> records,
    Map<String, String> conflictIds,
  ) async {
    savedRecords = List<Attendance>.from(records);
    savedConflictIds = Map<String, String>.from(conflictIds);
    for (final record in records) {
      conflictsByStudentId[record.studentId] = record;
    }
  }
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1080, 2200);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}
