import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/providers/heatmap_provider.dart';
import 'package:moyun/features/statistics/widgets/time_heatmap.dart';

void main() {
  testWidgets('heatmap cells expose readable labels and larger tap targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [heatmapProvider.overrideWith(_StaticHeatmapNotifier.new)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: TimeHeatmap(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final cell = find.bySemanticsLabel(
        '\u5468\u4e00 10:00\uff0c3 \u4eba\u6b21',
      );
      expect(cell, findsOneWidget);
      final cellSize = tester.getSize(cell);
      expect(cellSize.width, greaterThanOrEqualTo(44));
      expect(cellSize.height, greaterThanOrEqualTo(40));

      final cellNode = tester.getSemantics(cell);
      expect(cellNode.flagsCollection.isButton, isTrue);
      expect(
        cellNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      await tester.tap(cell);
      await tester.pump();

      expect(
        find.text('\u5468\u4e00 10:00\uff0c3 \u4eba\u6b21'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });
}

class _StaticHeatmapNotifier extends HeatmapNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return const [
      {'weekday': 1, 'hour': 10, 'count': 3},
    ];
  }
}
