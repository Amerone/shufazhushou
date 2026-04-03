import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/payment.dart';
import 'package:moyun/core/utils/ledger_record_validator.dart';

void main() {
  group('LedgerRecordValidator', () {
    test(
      'rejects attendance records whose fee does not match status pricing',
      () {
        final record = Attendance(
          id: 'attendance-1',
          studentId: 'student-1',
          date: '2026-04-01',
          startTime: '09:00',
          endTime: '10:00',
          status: 'leave',
          priceSnapshot: 180,
          feeAmount: 180,
          createdAt: 1,
          updatedAt: 1,
        );

        expect(
          () => LedgerRecordValidator.validateAttendance(record),
          throwsFormatException,
        );
      },
    );

    test('rejects payments with non-positive amount', () {
      const payment = Payment(
        id: 'payment-1',
        studentId: 'student-1',
        amount: 0,
        paymentDate: '2026-04-01',
        createdAt: 1,
      );

      expect(
        () => LedgerRecordValidator.validatePayment(payment),
        throwsFormatException,
      );
    });

    test('accepts well-formed attendance and payment records', () {
      final record = Attendance(
        id: 'attendance-1',
        studentId: 'student-1',
        date: '2026-04-01',
        startTime: '09:00',
        endTime: '10:00',
        status: 'present',
        priceSnapshot: 180,
        feeAmount: 180,
        createdAt: 1,
        updatedAt: 1,
      );
      const payment = Payment(
        id: 'payment-1',
        studentId: 'student-1',
        amount: 180,
        paymentDate: '2026-04-01',
        createdAt: 1,
      );

      expect(
        () => LedgerRecordValidator.validateAttendance(record),
        returnsNormally,
      );
      expect(
        () => LedgerRecordValidator.validatePayment(payment),
        returnsNormally,
      );
    });
  });
}
