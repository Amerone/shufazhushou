import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/widgets/empty_state.dart';

void main() {
  testWidgets('empty state exposes a live message and tappable CTA', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var actionCount = 0;

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: EmptyState(
              message: '还没有学生档案',
              actionLabel: '新增学生',
              onAction: () => actionCount++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('还没有学生档案'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '还没有学生档案' &&
              widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );

      final buttonNode = tester.getSemantics(find.bySemanticsLabel('新增学生'));
      expect(
        buttonNode.getSemanticsData().hasAction(SemanticsAction.tap),
        true,
      );
      expect(
        tester.getSize(find.widgetWithText(FilledButton, '新增学生')).height,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(find.text('新增学生'));

      expect(actionCount, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('empty state honors a custom semantic label', (tester) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: EmptyState(message: '暂无数据', semanticLabel: '统计图暂无数据'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无数据'), findsOneWidget);
      expect(find.bySemanticsLabel('统计图暂无数据'), findsOneWidget);
      expect(find.bySemanticsLabel('暂无数据'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
}
