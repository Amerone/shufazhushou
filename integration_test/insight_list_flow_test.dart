import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moyun/core/providers/insight_provider.dart';
import 'package:moyun/core/services/insight_aggregation_service.dart';
import 'package:moyun/features/statistics/widgets/insight_list.dart';
import 'package:moyun/shared/constants.dart';

class _FakeInsightNotifier extends InsightNotifier {
  static List<Insight> seededInsights = const [];

  @override
  Future<List<Insight>> build() async => seededInsights;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('statistics insight action navigates to student route', (
    tester,
  ) async {
    _FakeInsightNotifier.seededInsights = const [
      Insight(
        type: InsightType.churn,
        studentId: 'student-1',
        studentName: '张三',
        message: '已 24 天未出勤',
        suggestion: '建议尽快回访，确认学习节奏。',
        calcLogic: '最近一次正式出勤超过 21 天时触发。',
        dataFreshness: '2026-03-27 09:00',
      ),
    ];

    final router = GoRouter(
      initialLocation: '/statistics',
      routes: [
        GoRoute(
          path: '/statistics',
          builder: (context, state) {
            return const Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: InsightList(),
                  ),
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/students/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return Scaffold(
              body: SafeArea(child: Center(child: Text('student:$id'))),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [insightProvider.overrideWith(_FakeInsightNotifier.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _settleUi(tester);

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('已 24 天未出勤'), findsOneWidget);
    expect(find.textContaining('建议尽快回访'), findsWidgets);
    expect(find.textContaining('计算逻辑：最近一次正式出勤'), findsOneWidget);

    final actionButton = find.text('查看档案');
    expect(actionButton, findsOneWidget);
    await tester.tap(actionButton);
    await _settleUi(tester);

    expect(find.text('student:student-1'), findsOneWidget);
  });

  testWidgets('statistics insight renders progress metadata', (tester) async {
    _FakeInsightNotifier.seededInsights = const [
      Insight(
        type: InsightType.progress,
        studentId: 'student-2',
        studentName: '李四',
        message: '近 3 次评分持续提升：笔画质量、结构准确',
        suggestion: '建议生成成长快照并同步家长，延续当前训练节奏。',
        calcLogic: '在最近 3 次有效评分记录中，至少一个维度连续递增时触发。',
        dataFreshness: '2026-03-26 18:30',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [insightProvider.overrideWith(_FakeInsightNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: InsightList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.text('李四'), findsOneWidget);
    expect(find.text('近 3 次评分持续提升：笔画质量、结构准确'), findsOneWidget);
    expect(find.textContaining('建议生成成长快照'), findsOneWidget);
    expect(find.textContaining('计算逻辑：在最近 3 次有效评分记录中'), findsOneWidget);
    expect(find.text('数据截至 2026-03-26 18:30'), findsOneWidget);
  });
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
