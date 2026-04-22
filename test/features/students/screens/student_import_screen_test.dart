import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
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

      expect(find.bySemanticsLabel('步骤 1：选择模板文件'), findsOneWidget);
      expect(find.bySemanticsLabel('步骤 2：核对预览结果'), findsOneWidget);
      expect(find.bySemanticsLabel('步骤 3：确认批量导入'), findsOneWidget);
      expect(
        find.bySemanticsLabel('选择 Excel 文件，打开文件选择器并生成导入预览'),
        findsOneWidget,
      );
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

      expect(
        find.bySemanticsLabel('确认导入不可用，当前没有可导入的学生记录，请重新选择文件或修正 Excel 内容'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
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
