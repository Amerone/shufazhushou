import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/utils/excel_importer.dart';
import 'package:moyun/features/students/screens/student_import_screen.dart';
import 'package:moyun/shared/theme.dart';

void main() {
  testWidgets('exposes import steps and file picker action to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpScreen(tester);

      expect(find.bySemanticsLabel('步骤 1：选文件'), findsOneWidget);
      expect(find.bySemanticsLabel('步骤 2：看预览'), findsOneWidget);
      expect(find.bySemanticsLabel('步骤 3：导入'), findsOneWidget);
      expect(find.bySemanticsLabel('选择 Excel 文件并预览'), findsOneWidget);
      expect(find.text('空姓名、重复记录不会写入。'), findsOneWidget);
      expect(find.text('问题行会留在预览中。'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('announces preview issues and disabled confirm reason', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpScreen(
        tester,
        initialPreview: const ImportPreview(
          total: 1,
          skipped: 1,
          toInsert: [],
          errors: ['第 2 行：姓名为空，已跳过'],
        ),
      );

      expect(find.text('暂不可导入'), findsOneWidget);
      expect(find.bySemanticsLabel('导入问题 1：第 2 行：姓名为空，已跳过'), findsOneWidget);

      await tester.drag(find.byType(Scrollable), const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('确认导入不可用，没有可导入记录'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('keeps import protection copy with mixed preview results', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      initialPreview: ImportPreview(
        total: 3,
        skipped: 2,
        toInsert: [
          Student(
            id: 'student-1',
            name: '张三',
            parentName: '张妈妈',
            parentPhone: '13800000000',
            pricePerClass: 180,
            status: 'active',
            createdAt: 1,
            updatedAt: 1,
          ),
        ],
        errors: const ['第 2 行：姓名为空，已跳过'],
      ),
    );

    expect(find.text('空姓名、重复记录不会写入。'), findsOneWidget);
    expect(find.text('问题行会留在预览中。'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('另外有 1 条记录因同名且家长信息一致而自动跳过。'),
      300,
    );
    expect(find.text('另外有 1 条记录因同名且家长信息一致而自动跳过。'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('只写入有效学生。'), 300);
    expect(find.text('只写入有效学生。', skipOffstage: false), findsOneWidget);
    expect(
      find.bySemanticsLabel('确认导入 1 位学生', skipOffstage: false),
      findsOneWidget,
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  ImportPreview? initialPreview,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studentProvider.overrideWith(_FakeStudentNotifier.new)],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: StudentImportScreen(initialPreview: initialPreview),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeStudentNotifier extends StudentNotifier {
  @override
  Future<List<StudentWithMeta>> build() async => const <StudentWithMeta>[];
}
