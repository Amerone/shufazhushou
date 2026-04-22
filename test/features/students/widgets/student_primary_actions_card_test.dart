import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moyun/features/students/widgets/student_primary_actions_card.dart';

void main() {
  testWidgets('renders primary and secondary actions with callbacks', (
    tester,
  ) async {
    var paymentTapped = false;
    var attendanceTapped = false;
    var exportTapped = false;
    var editTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentPrimaryActionsCard(
            onOpenPayment: () => paymentTapped = true,
            onOpenAttendance: () => attendanceTapped = true,
            onOpenExport: () => exportTapped = true,
            onEditStudent: () => editTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('新增缴费'), findsOneWidget);
    expect(find.text('查看出勤'), findsOneWidget);
    expect(find.text('导出报告'), findsOneWidget);
    expect(find.text('编辑档案'), findsOneWidget);

    await tester.tap(find.text('新增缴费'));
    await tester.pump();
    await tester.tap(find.text('查看出勤'));
    await tester.pump();
    await tester.tap(find.text('导出报告'));
    await tester.pump();
    await tester.tap(find.text('编辑档案'));
    await tester.pump();

    expect(paymentTapped, isTrue);
    expect(attendanceTapped, isTrue);
    expect(exportTapped, isTrue);
    expect(editTapped, isTrue);
  });

  testWidgets('keeps actions usable on a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(340, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StudentPrimaryActionsCard(
              onOpenPayment: () {},
              onOpenAttendance: () {},
              onOpenExport: () {},
              onEditStudent: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('新增缴费'), findsOneWidget);
    expect(find.text('查看出勤'), findsOneWidget);
    expect(find.text('导出报告'), findsOneWidget);
    expect(find.text('编辑档案'), findsOneWidget);
  });
}
