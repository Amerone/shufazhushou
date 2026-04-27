import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/payment.dart';
import 'package:moyun/core/services/pdf_report_summary_service.dart';
import 'package:moyun/core/utils/fee_calculator.dart';

void main() {
  test('build sorts records and resolves ledger from fee summary', () {
    final summary = const PdfReportSummaryService().build(
      records: [
        Attendance(
          id: 'b',
          studentId: 's1',
          date: '2026-04-02',
          startTime: '10:00',
          endTime: '11:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
        Attendance(
          id: 'a',
          studentId: 's1',
          date: '2026-04-01',
          startTime: '09:00',
          endTime: '10:30',
          status: 'late',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      payments: [
        Payment(
          id: 'p1',
          studentId: 's1',
          amount: 50,
          paymentDate: '2026-04-03',
          createdAt: 1,
        ),
      ],
      pricePerClass: 100,
      feeSummary: const StudentFeeSummary(
        totalReceivable: 200,
        totalReceived: 50,
        openingBalance: 0,
        periodNetChange: -150,
        balance: -150,
      ),
      now: DateTime(2026, 4, 27),
    );

    expect(summary.sortedRecords.map((item) => item.id), ['a', 'b']);
    expect(summary.totalMinutes, 150);
    expect(summary.totalFee, 200);
    expect(summary.totalPaid, 50);
    expect(summary.ledger.balance, -150);
    expect(summary.feedbackRecords, isEmpty);
    expect(summary.growthSummary.dataFreshness, isNotEmpty);
  });

  test('build treats invalid or reversed lesson times as zero minutes', () {
    final summary = const PdfReportSummaryService().build(
      records: [
        Attendance(
          id: 'invalid',
          studentId: 's1',
          date: '2026-04-02',
          startTime: 'bad',
          endTime: '11:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
        Attendance(
          id: 'reversed',
          studentId: 's1',
          date: '2026-04-03',
          startTime: '12:00',
          endTime: '11:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      payments: const [],
      pricePerClass: 100,
      now: DateTime(2026, 4, 27),
    );

    expect(summary.totalMinutes, 0);
  });

  test('build preserves legacy partial time parsing fallback', () {
    final summary = const PdfReportSummaryService().build(
      records: [
        Attendance(
          id: 'invalid-start-hour',
          studentId: 's1',
          date: '2026-04-02',
          startTime: 'bad:30',
          endTime: '01:45',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
        Attendance(
          id: 'invalid-start-minute',
          studentId: 's1',
          date: '2026-04-03',
          startTime: '10:bad',
          endTime: '11:15',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      payments: const [],
      pricePerClass: 100,
      now: DateTime(2026, 4, 27),
    );

    expect(summary.totalMinutes, 150);
  });

  test('build excludes artwork-only records from feedback records', () {
    final summary = const PdfReportSummaryService().build(
      records: [
        Attendance(
          id: 'artwork-only',
          studentId: 's1',
          date: '2026-04-02',
          startTime: '10:00',
          endTime: '11:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          artworkImagePath: '/tmp/artwork.jpg',
          createdAt: 1,
          updatedAt: 1,
        ),
        Attendance(
          id: 'feedback',
          studentId: 's1',
          date: '2026-04-03',
          startTime: '10:00',
          endTime: '11:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          lessonFocusTags: ['structure'],
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      payments: const [],
      pricePerClass: 100,
      now: DateTime(2026, 4, 27),
    );

    expect(summary.feedbackRecords.map((record) => record.id), ['feedback']);
  });
}
