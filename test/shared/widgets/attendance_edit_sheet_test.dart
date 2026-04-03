import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/widgets/attendance_edit_sheet.dart';

void main() {
  testWidgets('attendance edit sheet shows live fee preview for status', (
    tester,
  ) async {
    final record = Attendance(
      id: 'attendance-1',
      studentId: 'student-1',
      date: '2026-04-03',
      startTime: '09:00',
      endTime: '10:00',
      status: 'present',
      priceSnapshot: 180,
      feeAmount: 180,
      createdAt: 1,
      updatedAt: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: AttendanceEditSheet(record: record)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('课时单价 ¥180'), findsOneWidget);
    expect(find.text('本次扣费 ¥180'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '请假'));
    await tester.pumpAndSettle();

    expect(find.text('本次扣费 ¥0'), findsOneWidget);
  });
}
