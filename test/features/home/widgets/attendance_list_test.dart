import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show DebugSemanticsDumpOrder, PipelineOwner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
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
import 'package:moyun/shared/widgets/empty_state.dart';

void main() {
  testWidgets('empty attendance state exposes direct quick entry action', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = [_seededStudent];
    _selectedDateAttendanceRecords = const [];

    await _pumpAttendanceList(tester);

    expect(find.text('立即记课'), findsOneWidget);
  });

  testWidgets('no-student state does not read attendance provider', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = const [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
          selectedDateAttendanceProvider.overrideWith(
            (ref) => throw StateError('attendance should not load'),
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
            ],
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.textContaining('attendance should not load'), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('attendance card shows direct payment and profile actions', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
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
      _expectTappableButtonSemantics(
        tester,
        find.bySemanticsLabel(RegExp('王小楷.*09:00到10:00.*轻触编辑')),
      );
      for (final label in ['作品分析', '记录缴费', '学生档案', '删除记录']) {
        _expectTappableButtonSemanticsLabel(tester, label);
      }
    } finally {
      semanticsHandle.dispose();
    }
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

void _expectTappableButtonSemantics(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final semanticsData = tester.getSemantics(finder).getSemanticsData();
  expect(semanticsData.flagsCollection.isButton, isTrue);
  expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);
}

void _expectTappableButtonSemanticsLabel(WidgetTester tester, Pattern label) {
  final semanticsData = _semanticsNodeWithLabel(
    tester,
    label,
  ).getSemanticsData();
  expect(semanticsData.flagsCollection.isButton, isTrue);
  expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);
}

SemanticsNode _semanticsNodeWithLabel(WidgetTester tester, Pattern label) {
  final matches = <SemanticsNode>[];

  void visit(SemanticsNode node) {
    final nodeLabel = node.getSemanticsData().label;
    if (label.allMatches(nodeLabel).isNotEmpty) {
      matches.add(node);
    }
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child);
    }
  }

  void visitOwner(PipelineOwner owner) {
    final root = owner.semanticsOwner?.rootSemanticsNode;
    if (root != null) {
      visit(root);
    }
    owner.visitChildren(visitOwner);
  }

  visitOwner(tester.binding.rootPipelineOwner);
  expect(
    matches,
    hasLength(1),
    reason: 'Expected one semantics node matching "$label".',
  );
  return matches.single;
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
