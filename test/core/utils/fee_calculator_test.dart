import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/payment_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/payment.dart';
import 'package:moyun/core/utils/fee_calculator.dart';
import 'package:moyun/shared/constants.dart';

void main() {
  group('FeeCalculator', () {
    test('calcFee only charges present and late attendance', () {
      expect(FeeCalculator.calcFee(AttendanceStatus.present, 180), 180);
      expect(FeeCalculator.calcFee(AttendanceStatus.late, 180), 180);
      expect(FeeCalculator.calcFee(AttendanceStatus.leave, 180), 0);
      expect(FeeCalculator.calcFee(AttendanceStatus.absent, 180), 0);
      expect(FeeCalculator.calcFee(AttendanceStatus.trial, 180), 0);
    });

    test('calcSummary keeps carry-over debt in current balance', () async {
      final attendanceDao = _FakeAttendanceDao([
        _attendance(id: 'a-1', date: '2026-03-28', feeAmount: 200),
        _attendance(id: 'a-2', date: '2026-04-10', feeAmount: 100),
      ]);
      final paymentDao = _FakePaymentDao([
        _payment(id: 'p-1', date: '2026-04-15', amount: 150),
      ]);

      final summary = await FeeCalculator.calcSummary(
        'student-1',
        attendanceDao,
        paymentDao,
        from: '2026-04-01',
        to: '2026-04-30',
      );

      expect(summary.totalReceivable, 100);
      expect(summary.totalReceived, 150);
      expect(summary.openingBalance, -200);
      expect(summary.periodNetChange, 50);
      expect(summary.balance, -150);
    });

    test('calcSummary clears prior debt after cross-month payment', () async {
      final attendanceDao = _FakeAttendanceDao([
        _attendance(id: 'a-1', date: '2026-03-28', feeAmount: 200),
      ]);
      final paymentDao = _FakePaymentDao([
        _payment(id: 'p-1', date: '2026-04-03', amount: 200),
      ]);

      final summary = await FeeCalculator.calcSummary(
        'student-1',
        attendanceDao,
        paymentDao,
        from: '2026-04-01',
        to: '2026-04-30',
      );

      expect(summary.totalReceivable, 0);
      expect(summary.totalReceived, 200);
      expect(summary.openingBalance, -200);
      expect(summary.periodNetChange, 200);
      expect(summary.balance, 0);
    });

    test('StudentLedgerView centralizes debt and renewal semantics', () {
      final debtLedger = StudentLedgerView.fromTotals(
        totalReceivable: 300,
        totalReceived: 100,
        pricePerClass: 100,
      );
      final renewalLedger = StudentLedgerView.fromTotals(
        totalReceivable: 100,
        totalReceived: 320,
        pricePerClass: 100,
      );

      expect(debtLedger.needsPaymentAttention, isTrue);
      expect(debtLedger.needsRenewalAttention, isFalse);
      expect(debtLedger.remainingLessons, -2);
      expect(debtLedger.balanceState, LedgerBalanceState.debt);
      expect(debtLedger.balanceStatusLabel, '待缴');
      expect(debtLedger.currentBalanceLabel, '截至当前待缴');

      expect(renewalLedger.needsPaymentAttention, isFalse);
      expect(renewalLedger.needsRenewalAttention, isTrue);
      expect(renewalLedger.remainingLessons, 2.2);
      expect(renewalLedger.balanceState, LedgerBalanceState.surplus);
      expect(renewalLedger.totalBalanceLabel, '总结余');
    });

    test(
      'calcSummary carries balance correctly across year boundary',
      () async {
        final attendanceDao = _FakeAttendanceDao([
          _attendance(id: 'a-1', date: '2025-12-29', feeAmount: 300),
          _attendance(id: 'a-2', date: '2026-01-05', feeAmount: 150),
        ]);
        final paymentDao = _FakePaymentDao([
          _payment(id: 'p-1', date: '2026-01-02', amount: 300),
          _payment(id: 'p-2', date: '2026-01-10', amount: 50),
        ]);

        final summary = await FeeCalculator.calcSummary(
          'student-1',
          attendanceDao,
          paymentDao,
          from: '2026-01-01',
          to: '2026-01-31',
        );

        expect(summary.totalReceivable, 150);
        expect(summary.totalReceived, 350);
        expect(summary.openingBalance, -300);
        expect(summary.periodNetChange, 200);
        expect(summary.balance, -100);
      },
    );

    test('resolveLedgerAmountState centralizes signed amount semantics', () {
      expect(resolveLedgerAmountState(-1), LedgerAmountState.negative);
      expect(resolveLedgerAmountState(0), LedgerAmountState.neutral);
      expect(resolveLedgerAmountState(1), LedgerAmountState.positive);
    });
  });
}

Attendance _attendance({
  required String id,
  required String date,
  required double feeAmount,
}) {
  return Attendance(
    id: id,
    studentId: 'student-1',
    date: date,
    startTime: '09:00',
    endTime: '10:00',
    status: 'present',
    priceSnapshot: feeAmount,
    feeAmount: feeAmount,
    createdAt: 1,
    updatedAt: 1,
  );
}

Payment _payment({
  required String id,
  required String date,
  required double amount,
}) {
  return Payment(
    id: id,
    studentId: 'student-1',
    amount: amount,
    paymentDate: date,
    createdAt: 1,
  );
}

class _FakeAttendanceDao extends AttendanceDao {
  final List<Attendance> attendance;

  _FakeAttendanceDao(this.attendance) : super(DatabaseHelper.instance);

  @override
  Future<double> getTotalFeeByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async {
    return attendance
        .where((item) => item.studentId == studentId)
        .where((item) => from == null || item.date.compareTo(from) >= 0)
        .where((item) => to == null || item.date.compareTo(to) <= 0)
        .fold<double>(0, (sum, item) => sum + item.feeAmount);
  }
}

class _FakePaymentDao extends PaymentDao {
  final List<Payment> payments;

  _FakePaymentDao(this.payments) : super(DatabaseHelper.instance);

  @override
  Future<double> getTotalByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async {
    return payments
        .where((item) => item.studentId == studentId)
        .where((item) => from == null || item.paymentDate.compareTo(from) >= 0)
        .where((item) => to == null || item.paymentDate.compareTo(to) <= 0)
        .fold<double>(0, (sum, item) => sum + item.amount);
  }
}
