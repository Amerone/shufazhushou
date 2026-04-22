import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moyun/core/database/dao/class_template_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/class_template.dart';
import 'package:moyun/core/providers/class_template_provider.dart';
import 'package:moyun/features/settings/screens/template_screen.dart';
import 'package:moyun/shared/theme.dart';

void main() {
  testWidgets('template FAB reserves room for shell navigation', (
    tester,
  ) async {
    await _pumpTemplateScreen(tester);

    expect(find.widgetWithText(FloatingActionButton, '新增模板'), findsOneWidget);

    final paddings = tester.widgetList<Padding>(
      find.ancestor(
        of: find.widgetWithText(FloatingActionButton, '新增模板'),
        matching: find.byType(Padding),
      ),
    );
    expect(
      paddings.any(
        (padding) => padding.padding.resolve(TextDirection.ltr).bottom >= 80,
      ),
      isTrue,
    );
  });

  testWidgets('template actions stay readable on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTemplateScreen(
      tester,
      templates: const [
        ClassTemplate(
          id: 'custom',
          name: '超长模板名称用于验证小屏操作不挤压标题',
          startTime: '18:00',
          endTime: '19:00',
          createdAt: 1,
        ),
      ],
    );

    expect(find.widgetWithText(OutlinedButton, '编辑'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '删除'), findsOneWidget);
  });
}

Future<void> _pumpTemplateScreen(
  WidgetTester tester, {
  List<ClassTemplate> templates = const [
    ClassTemplate(
      id: 'builtin',
      name: '周内 18:00-19:00',
      startTime: '18:00',
      endTime: '19:00',
      createdAt: 1,
    ),
  ],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        classTemplateDaoProvider.overrideWithValue(
          _FakeClassTemplateDao(templates),
        ),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const TemplateScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeClassTemplateDao extends ClassTemplateDao {
  _FakeClassTemplateDao(List<ClassTemplate> templates)
    : _templates = List<ClassTemplate>.from(templates),
      super(DatabaseHelper.instance);

  final List<ClassTemplate> _templates;

  @override
  Future<int> ensureBuiltinTemplates({bool force = false}) async => 0;

  @override
  Future<List<ClassTemplate>> getAll() async =>
      List<ClassTemplate>.from(_templates);
}
