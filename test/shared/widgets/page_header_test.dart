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
                trailing: TextButton(onPressed: () {}, child: const Text('操作')),
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
}
