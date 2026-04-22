import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/contribution_provider.dart';
import 'package:moyun/core/providers/heatmap_provider.dart';
import 'package:moyun/core/providers/insight_provider.dart';
import 'package:moyun/core/providers/metrics_provider.dart';
import 'package:moyun/core/providers/revenue_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/statistics_period_provider.dart';
import 'package:moyun/core/providers/status_distribution_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/services/insight_aggregation_service.dart';
import 'package:moyun/features/statistics/screens/statistics_screen.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  testWidgets('period and export controls expose stateful semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpStatisticsScreen(tester);

      final periodControl = find.bySemanticsLabel('\u7edf\u8ba1\u5468\u671f');
      expect(periodControl, findsOneWidget);
      final periodNode = tester.getSemantics(periodControl);
      expect(periodNode.value, '\u672c\u6708');
      expect(
        periodNode.hint,
        '\u5de6\u53f3\u6ed1\u52a8\u67e5\u770b\u5468\u671f\u9009\u9879\uff0c\u70b9\u6309\u53ef\u5207\u6362\u7edf\u8ba1\u8303\u56f4',
      );

      final exportAction = find.bySemanticsLabel(
        '\u5bfc\u51fa\u5f53\u524d\u5468\u671f\u660e\u7ec6',
      );
      expect(exportAction, findsOneWidget);
      final exportNode = tester.getSemantics(exportAction);
      expect(exportNode.flagsCollection.isButton, isTrue);
      expect(exportNode.value, '\u672c\u6708');
      expect(
        exportNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('quick navigator exposes concise jump semantics', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final semantics = tester.ensureSemantics();
    try {
      await _pumpStatisticsScreen(tester);

      final navigatorNode = tester.getSemantics(
        find.bySemanticsLabel('\u7edf\u8ba1\u9875\u5feb\u901f\u8df3\u8f6c'),
      );
      expect(
        navigatorNode.hint,
        '\u5de6\u53f3\u6ed1\u52a8\u67e5\u770b\u5206\u533a\uff0c\u70b9\u6309\u53ef\u8df3\u8f6c\u5230\u5bf9\u5e94\u7edf\u8ba1\u6a21\u5757',
      );

      final metricsChip = find.bySemanticsLabel(
        '\u8df3\u8f6c\u5230\u6307\u6807',
      );
      expect(metricsChip, findsOneWidget);
      expect(tester.getSize(metricsChip).height, greaterThanOrEqualTo(44));

      var metricsNode = tester.getSemantics(metricsChip);
      expect(metricsNode.flagsCollection.isButton, isTrue);
      expect(
        _semanticsFlagIsTrue(metricsNode.flagsCollection.isSelected),
        isFalse,
      );
      expect(
        metricsNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        metricsNode.hint,
        '\u70b9\u6309\u8df3\u8f6c\u5230\u6307\u6807\u5206\u533a',
      );

      await tester.tap(metricsChip);
      await tester.pumpAndSettle();

      metricsNode = tester.getSemantics(metricsChip);
      expect(
        _semanticsFlagIsTrue(metricsNode.flagsCollection.isSelected),
        isTrue,
      );
      expect(
        metricsNode.hint,
        '\u5f53\u524d\u6240\u5728\u5206\u533a\uff0c\u70b9\u6309\u53ef\u91cd\u65b0\u5b9a\u4f4d\u5230\u6307\u6807',
      );
    } finally {
      semantics.dispose();
    }
  });
}

bool _semanticsFlagIsTrue(Object flag) {
  return flag.toString().contains('isTrue');
}

Future<void> _pumpStatisticsScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        statisticsNowProvider.overrideWith((ref) => DateTime(2026, 4, 3)),
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        studentProvider.overrideWith(_FakeStudentNotifier.new),
        metricsProvider.overrideWith(_StaticMetricsNotifier.new),
        revenueProvider.overrideWith(_StaticRevenueNotifier.new),
        contributionProvider.overrideWith(_EmptyContributionNotifier.new),
        statusDistributionProvider.overrideWith(
          _EmptyStatusDistributionNotifier.new,
        ),
        heatmapProvider.overrideWith(_EmptyHeatmapNotifier.new),
        insightProvider.overrideWith(_EmptyInsightNotifier.new),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const StatisticsScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<Map<String, String>> build() async => const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };
}

class _FakeStudentNotifier extends StudentNotifier {
  @override
  Future<List<StudentWithMeta>> build() async => const [
    StudentWithMeta(
      Student(
        id: 'student-1',
        name: 'Alice',
        pricePerClass: 180,
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
      ),
      null,
    ),
  ];
}

class _StaticMetricsNotifier extends MetricsNotifier {
  @override
  Future<MetricsData> build() async => const MetricsData(
    totalReceivable: 180,
    totalReceived: 180,
    presentCount: 1,
    lateCount: 0,
    absentCount: 0,
    activeStudentCount: 1,
  );
}

class _StaticRevenueNotifier extends RevenueNotifier {
  @override
  Future<RevenueData> build() async => const RevenueData(
    monthlyReceivable: [
      {'month': '2026-04', 'totalFee': 180.0},
    ],
    monthlyReceived: [
      {'month': '2026-04', 'totalReceived': 180.0},
    ],
  );
}

class _EmptyContributionNotifier extends ContributionNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async => const [];
}

class _EmptyStatusDistributionNotifier extends StatusDistributionNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async => const [];
}

class _EmptyHeatmapNotifier extends HeatmapNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async => const [];
}

class _EmptyInsightNotifier extends InsightNotifier {
  @override
  Future<List<Insight>> build() async => const [];
}
