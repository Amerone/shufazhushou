import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/providers/home_workbench_provider.dart';
import 'package:moyun/core/providers/invalidation_helper.dart';
import 'package:moyun/core/services/home_workbench_service.dart';

void main() {
  setUp(_FakeHomeWorkbenchOverride.reset);

  testWidgets('attendance invalidation refreshes home workbench provider', (
    tester,
  ) async {
    await _pumpHarness(tester, onPressed: invalidateAfterAttendanceChange);

    expect(find.text('tasks:1'), findsOneWidget);
    expect(_FakeHomeWorkbenchOverride.buildCount, 1);

    await tester.tap(find.text('invalidate'));
    await _settleUi(tester);

    expect(find.text('tasks:0'), findsOneWidget);
    expect(_FakeHomeWorkbenchOverride.buildCount, 2);
  });

  testWidgets('payment invalidation refreshes home workbench provider', (
    tester,
  ) async {
    await _pumpHarness(tester, onPressed: invalidateAfterPaymentChange);

    expect(find.text('tasks:1'), findsOneWidget);
    expect(_FakeHomeWorkbenchOverride.buildCount, 1);

    await tester.tap(find.text('invalidate'));
    await _settleUi(tester);

    expect(find.text('tasks:0'), findsOneWidget);
    expect(_FakeHomeWorkbenchOverride.buildCount, 2);
  });

  testWidgets('student invalidation refreshes home workbench provider', (
    tester,
  ) async {
    await _pumpHarness(tester, onPressed: invalidateAfterStudentChange);

    expect(find.text('tasks:1'), findsOneWidget);
    expect(_FakeHomeWorkbenchOverride.buildCount, 1);

    await tester.tap(find.text('invalidate'));
    await _settleUi(tester);

    expect(find.text('tasks:0'), findsOneWidget);
    expect(_FakeHomeWorkbenchOverride.buildCount, 2);
  });
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required void Function(WidgetRef ref) onPressed,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeWorkbenchProvider.overrideWith(_FakeHomeWorkbenchOverride.build),
      ],
      child: MaterialApp(
        home: Scaffold(body: _InvalidationHarness(onPressed: onPressed)),
      ),
    ),
  );
  await _settleUi(tester);
}

class _InvalidationHarness extends ConsumerWidget {
  final void Function(WidgetRef ref) onPressed;

  const _InvalidationHarness({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(homeWorkbenchProvider);
    final taskCount = tasksAsync.valueOrNull?.length ?? -1;

    return Column(
      children: [
        Text('tasks:$taskCount'),
        TextButton(
          onPressed: () => onPressed(ref),
          child: const Text('invalidate'),
        ),
      ],
    );
  }
}

class _FakeHomeWorkbenchOverride {
  static int buildCount = 0;

  static void reset() {
    buildCount = 0;
  }

  static Future<List<HomeWorkbenchTask>> build(Ref ref) async {
    buildCount++;
    if (buildCount == 1) {
      return const [
        HomeWorkbenchTask(
          type: HomeWorkbenchTaskType.reportReady,
          title: 'Bella 可整理月报',
          summary: '本月已完成 2 节正式课程，适合整理家长版学习快照。',
          actionLabel: '生成月报',
          studentId: 'student-2',
        ),
      ];
    }
    return const [];
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
