import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/widgets/page_header.dart';

void main() {
  testWidgets('page header keeps back target accessible on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final semantics = tester.ensureSemantics();

    try {
      var backTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: Scaffold(
              body: PageHeader(
                title: '很长的页面标题需要保持可读和可返回',
                subtitle: '辅助说明文字也可能换行。',
                trailing: TextButton(
                  key: const ValueKey('header-action'),
                  onPressed: () {},
                  child: const Text('操作'),
                ),
                onBack: () => backTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final backButtonSize = tester.getSize(find.byTooltip('返回'));
      expect(backButtonSize.width, greaterThanOrEqualTo(48));
      expect(backButtonSize.height, greaterThanOrEqualTo(48));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('header-action'))).dy,
        greaterThan(tester.getBottomLeft(find.byTooltip('返回')).dy),
      );

      final titleNode = tester.getSemantics(
        find.bySemanticsLabel('很长的页面标题需要保持可读和可返回'),
      );
      expect(titleNode.flagsCollection.isHeader, isTrue);

      await tester.tap(find.byTooltip('返回'));
      expect(backTapped, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('page header keeps trailing action inline when width allows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: PageHeader(
            title: '学生档案',
            subtitle: '查看学生状态和最近记录',
            trailing: IconButton(
              key: const ValueKey('header-edit'),
              tooltip: '编辑',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {},
            ),
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('header-edit'))).dy,
      lessThan(tester.getBottomLeft(find.byTooltip('返回')).dy),
    );
  });
}
