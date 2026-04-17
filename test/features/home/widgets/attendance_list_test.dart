import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/home/widgets/attendance_list.dart';
import 'package:moyun/shared/constants.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';
import 'package:moyun/shared/widgets/attendance_artwork_preview.dart';

void main() {
  testWidgets('empty attendance state exposes direct quick entry action', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = [_seededStudent];
    _selectedDateAttendanceRecords = const [];

    await _pumpAttendanceList(tester);

    expect(find.text('立即记课'), findsOneWidget);
  });

  testWidgets('attendance card shows direct payment and profile actions', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = [_seededStudent];
    _selectedDateAttendanceRecords = [_seededAttendance];

    await _pumpAttendanceList(tester);

    expect(find.text('作品分析'), findsOneWidget);
    expect(find.text('记录缴费'), findsOneWidget);
    expect(find.text('学生档案'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('王小楷.*09:00到10:00.*轻触编辑')),
      findsOneWidget,
    );
  });

  testWidgets('attendance card shows uploaded artwork preview', (tester) async {
    _FakeStudentNotifier.seededStudents = [_seededStudent];
    _selectedDateAttendanceRecords = [
      _seededAttendance.copyWith(artworkImagePath: 'E:/missing/artwork.jpg'),
    ];

    await _pumpAttendanceList(tester);

    expect(find.byType(AttendanceArtworkPreview), findsOneWidget);
    expect(find.text('本次课堂作品'), findsOneWidget);
  });
}

final _seededStudent = StudentWithMeta(
  const Student(
    id: 'student-1',
    name: '王小楷',
    parentName: '王妈妈',
    parentPhone: '13900000001',
    pricePerClass: 180,
    status: 'active',
    createdAt: 1,
    updatedAt: 1,
  ),
  formatDate(DateTime.now()),
);

final _seededAttendance = Attendance(
  id: 'attendance-1',
  studentId: 'student-1',
  date: formatDate(DateTime.now()),
  startTime: '09:00',
  endTime: '10:00',
  status: 'present',
  priceSnapshot: 180,
  feeAmount: 180,
  createdAt: 1,
  updatedAt: 1,
);

List<Attendance> _selectedDateAttendanceRecords = const [];

Future<void> _pumpAttendanceList(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        studentProvider.overrideWith(_FakeStudentNotifier.new),
        selectedDateAttendanceProvider.overrideWith(
          (ref) async => _selectedDateAttendanceRecords,
        ),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: AttendanceList(),
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/students/:id',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Text('student:${state.pathParameters['id']}'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await _settleUi(tester);
}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<Map<String, String>> build() async => const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}
