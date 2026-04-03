import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/utils/fee_calculator.dart';
import 'package:moyun/features/students/widgets/student_finance_overview_card.dart';
import 'package:moyun/shared/theme.dart';

void main() {
  testWidgets('shows debt semantics from centralized ledger view', (
    tester,
  ) async {
    const student = Student(
      id: 'student-1',
      name: 'Alice',
      pricePerClass: 100,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    );
    const monthlyFee = StudentFeeSummary(
      totalReceivable: 300,
      totalReceived: 100,
      openingBalance: -50,
      periodNetChange: -200,
      balance: -250,
    );
    const allTimeFee = StudentFeeSummary(
      totalReceivable: 600,
      totalReceived: 350,
      openingBalance: 0,
      periodNetChange: -250,
      balance: -250,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: StudentFinanceOverviewCard(
              student: student,
              from: '2026-04-01',
              to: '2026-04-30',
              monthlyFeeAsync: AsyncData(monthlyFee),
              allTimeFeeAsync: AsyncData(allTimeFee),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('截至当前待缴'), findsOneWidget);
    expect(find.text('总待缴'), findsOneWidget);
    expect(find.text('期初结转 ¥-50.00'), findsOneWidget);
    expect(find.text('本期变化 ¥-200.00'), findsOneWidget);
  });
}
