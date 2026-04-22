import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/shared/widgets/async_value_widget.dart';

void main() {
  testWidgets('async value widget exposes loading semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: AsyncValueWidget<int>(
          value: AsyncValue.loading(),
          builder: _NeverBuilt.new,
        ),
      ),
    );

    try {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '正在加载' &&
              widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('async value widget keeps retry readable and actionable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AsyncValueWidget<int>(
          value: AsyncValue.error(Exception('数据库连接失败'), StackTrace.empty),
          onRetry: () => retryCount++,
          builder: (value) => Text('$value'),
        ),
      ),
    );

    try {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '加载失败，数据访问出现问题，请重试' &&
              widget.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));

      expect(retryCount, 1);
    } finally {
      semantics.dispose();
    }
  });
}

class _NeverBuilt extends StatelessWidget {
  const _NeverBuilt(this.value);

  final int value;

  @override
  Widget build(BuildContext context) {
    throw StateError('loading state should not build data content');
  }
}
