import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/students/widgets/student_picker_sheet.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  testWidgets('student picker surfaces recent attendance students first', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = [
      StudentWithMeta(
        const Student(
          id: 'student-1',
          name: '最近上课',
          parentName: '家长A',
          parentPhone: '13900000001',
          pricePerClass: 180,
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
        ),
        '2026-04-01',
      ),
      StudentWithMeta(
        const Student(
          id: 'student-2',
          name: '未记课',
          parentName: '家长B',
          parentPhone: '13900000002',
          pricePerClass: 180,
          status: 'active',
          createdAt: 2,
          updatedAt: 2,
        ),
        null,
      ),
      StudentWithMeta(
        const Student(
          id: 'student-3',
          name: '较早上课',
          parentName: '家长C',
          parentPhone: '13900000003',
          pricePerClass: 180,
          status: 'active',
          createdAt: 3,
          updatedAt: 3,
        ),
        '2026-03-20',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: StudentPickerSheet(
              title: '选择学生',
              subtitle: '用于记录缴费',
              actionLabel: '记录缴费',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('最近上课优先。'), findsOneWidget);
    expect(find.text('最近上课 2026-04-01'), findsOneWidget);
    expect(find.text('未记过课'), findsOneWidget);

    final recentTop = tester.getTopLeft(find.text('最近上课')).dy;
    final olderTop = tester.getTopLeft(find.text('较早上课')).dy;
    final neverTop = tester.getTopLeft(find.text('未记课')).dy;

    expect(recentTop, lessThan(olderTop));
    expect(olderTop, lessThan(neverTop));
  });

  testWidgets('student picker row has one semantic button selection action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    _FakeStudentNotifier.seededStudents = [
      StudentWithMeta(
        const Student(
          id: 'student-a',
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
    ];
    StudentWithMeta? selected;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      showModalBottomSheet<StudentWithMeta>(
                        context: context,
                        builder: (_) => const StudentPickerSheet(
                          title: 'Pick student',
                          subtitle: 'Choose one student',
                          actionLabel: 'Select',
                        ),
                      ).then((value) => selected = value);
                    },
                    child: const Text('Open picker'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Select'), findsNothing);
    expect(find.text('Select'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Alice Select')),
      matchesSemantics(
        label: 'Alice Select',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Select'), findsNothing);
    semantics.dispose();

    final studentRow = find.ancestor(
      of: find.text('Alice'),
      matching: find.byType(InkWell),
    );
    expect(studentRow, findsOneWidget);
    final rowInkWell = tester.widget<InkWell>(studentRow);
    expect(rowInkWell.onTap, isNotNull);
    await tester.runAsync(() async {
      rowInkWell.onTap!();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Pick student'), findsNothing);
    expect(selected?.student.id, 'student-a');
  });

  testWidgets('student picker activeOnly hides suspended students', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = [
      StudentWithMeta(
        const Student(
          id: 'student-active',
          name: 'Active Student',
          pricePerClass: 180,
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
        ),
        null,
      ),
      StudentWithMeta(
        const Student(
          id: 'student-suspended',
          name: 'Suspended Student',
          pricePerClass: 180,
          status: 'suspended',
          createdAt: 2,
          updatedAt: 2,
        ),
        null,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: StudentPickerSheet(
              title: '选择学生',
              subtitle: '选择一名在读学生',
              activeOnly: true,
              actionLabel: '选择',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active Student'), findsOneWidget);
    expect(find.text('Suspended Student'), findsNothing);
  });

  testWidgets('student picker empty search can be cleared inline', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = [
      StudentWithMeta(
        const Student(
          id: 'student-a',
          name: 'Alice',
          pricePerClass: 180,
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
        ),
        null,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: StudentPickerSheet(
              title: '选择学生',
              subtitle: '选择一名学生',
              actionLabel: '选择',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Missing');
    await tester.pump();

    expect(find.text('没有匹配学生。'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '清空搜索'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '清空搜索'));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('没有匹配学生。'), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
  });

  testWidgets('student picker error state exposes retry action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studentProvider.overrideWith(_ThrowingStudentNotifier.new)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: StudentPickerSheet(
              title: '选择学生',
              subtitle: '用于记录缴费',
              actionLabel: '记录缴费',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('加载学生失败'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '重试'), findsOneWidget);
  });
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;
}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<Map<String, String>> build() async => const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };
}

class _ThrowingStudentNotifier extends StudentNotifier {
  @override
  Future<List<StudentWithMeta>> build() async {
    throw StateError('student list failed');
  }
}
