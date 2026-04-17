import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/dismissed_insight_dao.dart';
import 'package:moyun/core/models/dismissed_insight.dart';
import 'package:moyun/core/providers/home_workbench_provider.dart';
import 'package:moyun/core/providers/insight_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/services/home_workbench_service.dart';
import 'package:moyun/features/home/widgets/home_workbench_panel.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  testWidgets('renders dismiss affordance for report-ready task', (
    tester,
  ) async {
    _setLargeViewport(tester);
    _mockPlatformChannel(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeWorkbenchProvider.overrideWith((ref) async {
            return const [
              HomeWorkbenchTask(
                type: HomeWorkbenchTaskType.reportReady,
                title: 'Chris report ready',
                summary: 'Two formal lessons already completed this month.',
                actionLabel: 'Generate report',
                studentId: 'student-3',
                studentName: 'Chris',
              ),
            ];
          }),
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: HomeWorkbenchPanel(),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.textContaining('Chris report ready'), findsOneWidget);
    expect(find.textContaining('Generate report'), findsOneWidget);
    expect(find.textContaining('7'), findsWidgets);
    expect(find.byType(TextButton), findsOneWidget);
  });

  testWidgets('dismisses report-ready task and refreshes the panel', (
    tester,
  ) async {
    _setLargeViewport(tester);
    _mockPlatformChannel(tester);
    final fakeDao = _FakeDismissedInsightDao();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dismissedInsightDaoProvider.overrideWithValue(fakeDao),
          homeWorkbenchProvider.overrideWith((ref) async {
            return const [
              HomeWorkbenchTask(
                type: HomeWorkbenchTaskType.reportReady,
                title: 'Chris report ready',
                summary: 'Two formal lessons already completed this month.',
                actionLabel: 'Generate report',
                studentId: 'student-3',
                studentName: 'Chris',
              ),
            ];
          }),
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: HomeWorkbenchPanel(),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    final dismissButton = find.widgetWithText(TextButton, '稍后 7 天');
    expect(dismissButton, findsOneWidget);

    tester.widget<TextButton>(dismissButton).onPressed!.call();
    await _settleUi(tester);

    expect(fakeDao.inserted, hasLength(1));
    expect(
      fakeDao.inserted.single.insightType,
      homeWorkbenchReportReadyDismissType,
    );
    expect(fakeDao.inserted.single.studentId, 'student-3');
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<Map<String, String>> build() async => const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };
}

class _FakeDismissedInsightDao extends DismissedInsightDao {
  final List<DismissedInsight> inserted = <DismissedInsight>[];

  _FakeDismissedInsightDao() : super(DatabaseHelper.instance);

  @override
  Future<void> insert(DismissedInsight record) async {
    inserted.removeWhere(
      (item) =>
          item.insightType == record.insightType &&
          item.studentId == record.studentId,
    );
    inserted.add(record);
  }

  @override
  Future<Set<String>> getAllActiveKeys({DateTime? now}) async {
    return inserted
        .map((item) => '${item.insightType}:${item.studentId ?? ''}')
        .toSet();
  }
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _mockPlatformChannel(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (_) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}
