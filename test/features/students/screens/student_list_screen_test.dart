import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/students/screens/student_list_screen.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';
import 'package:moyun/shared/widgets/glass_card.dart';

void main() {
  testWidgets('shows visible create and import entries on first screen', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = _seededStudents;

    await _pumpScreen(tester);

    expect(find.text('新增学生'), findsOneWidget);
    expect(find.text('批量导入'), findsOneWidget);
  });

  testWidgets('filters student list by selected status', (tester) async {
    _FakeStudentNotifier.seededStudents = _seededStudents;

    await _pumpScreen(tester);
    final verticalScrollable = find.byType(Scrollable).first;

    final filterButton = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is SegmentedButton),
      matching: find.text('休学'),
    );
    await tester.tap(filterButton);
    await _settleUi(tester);
    await tester.drag(verticalScrollable, const Offset(0, -900));
    await _settleUi(tester);

    expect(find.textContaining('1 / 3'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Carol'), findsNothing);
  });

  testWidgets('shows direct payment entry on student cards', (tester) async {
    _FakeStudentNotifier.seededStudents = _seededStudents;

    await _pumpScreen(tester);
    final verticalScrollable = find.byType(Scrollable).first;
    await tester.drag(verticalScrollable, const Offset(0, -900));
    await _settleUi(tester);

    expect(find.text('记录缴费'), findsAtLeastNWidgets(1));
  });

  testWidgets('clears search query and restores full list', (tester) async {
    _FakeStudentNotifier.seededStudents = _seededStudents;

    await _pumpScreen(tester);
    final verticalScrollable = find.byType(Scrollable).first;

    await tester.enterText(find.byType(TextField), 'Carol');
    await _settleUi(tester);
    await tester.drag(verticalScrollable, const Offset(0, -900));
    await _settleUi(tester);

    expect(find.textContaining('1 / 3'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GlassCard).last,
        matching: find.text('Carol'),
      ),
      findsOneWidget,
    );
    expect(find.text('Alice'), findsNothing);

    await tester.drag(verticalScrollable, const Offset(0, 900));
    await _settleUi(tester);
    await tester.tap(find.byIcon(Icons.close));
    await _settleUi(tester);

    expect(find.textContaining('3 位学生'), findsWidgets);
    expect(find.textContaining('1 / 3'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
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
    '2026-03-30',
  ),
  StudentWithMeta(
    const Student(
      id: 'student-2',
      name: 'Bob',
      parentName: 'Parent B',
      parentPhone: '13900000002',
      pricePerClass: 200,
      status: 'suspended',
      createdAt: 2,
      updatedAt: 2,
    ),
    '2026-03-21',
  ),
  StudentWithMeta(
    const Student(
      id: 'student-3',
      name: 'Carol',
      parentName: 'Parent C',
      parentPhone: '13900000003',
      pricePerClass: 220,
      status: 'active',
      createdAt: 3,
      updatedAt: 3,
    ),
    null,
  ),
];

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        studentProvider.overrideWith(_FakeStudentNotifier.new),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const StudentListScreen(),
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
