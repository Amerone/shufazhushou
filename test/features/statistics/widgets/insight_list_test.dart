import 'package:calligraphy_assistant/core/database/dao/dismissed_insight_dao.dart';
import 'package:calligraphy_assistant/core/database/database_helper.dart';
import 'package:calligraphy_assistant/core/models/dismissed_insight.dart';
import 'package:calligraphy_assistant/core/providers/insight_provider.dart';
import 'package:calligraphy_assistant/core/services/insight_aggregation_service.dart';
import 'package:calligraphy_assistant/features/statistics/widgets/insight_list.dart';
import 'package:calligraphy_assistant/shared/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ignore action persists dismissal and refreshes empty state', (
    tester,
  ) async {
    final fakeDao = _FakeDismissedInsightDao();
    _DismissCycleNotifier.dao = fakeDao;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dismissedInsightDaoProvider.overrideWithValue(fakeDao),
          insightProvider.overrideWith(_DismissCycleNotifier.new),
        ],
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

    expect(find.text('张三'), findsOneWidget);
    expect(find.textContaining('稍后'), findsOneWidget);

    await tester.tap(find.textContaining('稍后'));
    await _settleUi(tester);

    expect(fakeDao.inserted, hasLength(1));
    expect(fakeDao.inserted.single.insightType, InsightType.renewal.name);
    expect(fakeDao.inserted.single.studentId, 'student-1');
    expect(fakeDao.inserted.single.dismissedAt, greaterThan(0));
    expect(find.text('笔墨安然，暂无提醒'), findsOneWidget);
  });

  testWidgets('primary action navigates to student detail route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightProvider.overrideWith(_StaticInsightNotifier.new),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
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
                  return Scaffold(
                    body: Center(
                      child: Text('student:${state.pathParameters['id']}'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.text('张三'), findsOneWidget);

    Finder actionButton = find.text('前往处理');
    if (actionButton.evaluate().isEmpty) {
      actionButton = find.text('前往学生页处理');
    }

    expect(actionButton, findsOneWidget);
    await tester.tap(actionButton);
    await _settleUi(tester);

    expect(find.text('student:student-1'), findsOneWidget);
  });
}

class _DismissCycleNotifier extends InsightNotifier {
  static _FakeDismissedInsightDao? dao;

  @override
  Future<List<Insight>> build() async {
    if (dao!.inserted.isNotEmpty) {
      return const [];
    }
    return const [
      Insight(
        type: InsightType.renewal,
        studentId: 'student-1',
        studentName: '张三',
        message: '余额 ¥120.00，约剩 1.2 节',
        suggestion: '建议本周内发起续费沟通，并同步下一阶段课程安排建议。',
        calcLogic: '当余额小于 ¥300 或剩余课次少于 3.0 节时触发。',
        dataFreshness: '2026-03-27 09:00',
      ),
    ];
  }
}

class _FakeDismissedInsightDao extends DismissedInsightDao {
  final List<DismissedInsight> inserted = [];

  _FakeDismissedInsightDao() : super(DatabaseHelper.instance);

  @override
  Future<void> insert(DismissedInsight r) async {
    inserted.add(r);
  }
}

class _StaticInsightNotifier extends InsightNotifier {
  @override
  Future<List<Insight>> build() async {
    return const [
      Insight(
        type: InsightType.debt,
        studentId: 'student-1',
        studentName: '张三',
        message: '欠费 ¥120.00',
        suggestion: '建议优先核对账单，并尽快联系家长确认补缴或续费安排。',
        calcLogic: '累计余额 = 累计已收 - 累计应收；当余额小于 0 时触发欠费提醒。',
        dataFreshness: '2026-03-27 09:00',
      ),
    ];
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
