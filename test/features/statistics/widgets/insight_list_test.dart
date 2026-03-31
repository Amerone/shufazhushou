import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moyun/core/database/dao/dismissed_insight_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/dismissed_insight.dart';
import 'package:moyun/core/providers/insight_provider.dart';
import 'package:moyun/core/services/insight_aggregation_service.dart';
import 'package:moyun/features/statistics/widgets/insight_list.dart';
import 'package:moyun/shared/constants.dart';

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

    expect(find.text('Alex'), findsOneWidget);
    expect(find.textContaining('\u7a0d\u540e'), findsOneWidget);

    await tester.tap(find.textContaining('\u7a0d\u540e'));
    await _settleUi(tester);

    expect(fakeDao.inserted, hasLength(1));
    expect(fakeDao.inserted.single.insightType, InsightType.renewal.name);
    expect(fakeDao.inserted.single.studentId, 'student-1');
    expect(fakeDao.inserted.single.dismissedAt, greaterThan(0));
    expect(find.text('\u7b14\u58a8\u5b89\u7136\uff0c\u6682\u65e0\u63d0\u9192'), findsOneWidget);
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
                      child: Text("student:${state.pathParameters['id']}"),
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

    expect(find.text('Alex'), findsOneWidget);

    Finder actionButton = find.text('\u524d\u5f80\u5904\u7406');
    if (actionButton.evaluate().isEmpty) {
      actionButton = find.text('\u524d\u5f80\u5b66\u751f\u9875\u5904\u7406');
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
        studentName: 'Alex',
        message: 'Balance reminder',
        suggestion: 'Follow up this week.',
        calcLogic: 'Triggered when renewal balance is low.',
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
        studentName: 'Alex',
        message: 'Outstanding balance',
        suggestion: 'Contact parent to confirm payment.',
        calcLogic: 'Shown when the current balance is negative.',
        dataFreshness: '2026-03-27 09:00',
      ),
    ];
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
