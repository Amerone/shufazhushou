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
}
