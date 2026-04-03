import '../../shared/constants.dart';
import '../models/attendance.dart';
import '../models/payment.dart';
import 'fee_calculator.dart';

class LedgerRecordValidator {
  static void validateAttendance(Attendance record) {
    _requireValidDate(record.date, fieldName: 'attendance.date');
    _requireValidTime(record.startTime, fieldName: 'attendance.startTime');
    _requireValidTime(record.endTime, fieldName: 'attendance.endTime');

    if (!_isEndAfterStart(record.startTime, record.endTime)) {
      throw const FormatException(
        'attendance.endTime must be later than startTime',
      );
    }

    if (!record.priceSnapshot.isFinite || record.priceSnapshot < 0) {
      throw const FormatException(
        'attendance.priceSnapshot must be a finite non-negative number',
      );
    }
    if (!record.feeAmount.isFinite || record.feeAmount < 0) {
      throw const FormatException(
        'attendance.feeAmount must be a finite non-negative number',
      );
    }

    final status = AttendanceStatus.values.asNameMap()[record.status];
    if (status == null) {
      throw FormatException('attendance.status is invalid: ${record.status}');
    }

    final expectedFee = FeeCalculator.calcFee(status, record.priceSnapshot);
    if ((record.feeAmount - expectedFee).abs() > 0.0001) {
      throw FormatException(
        'attendance.feeAmount does not match status pricing: '
        'expected $expectedFee, got ${record.feeAmount}',
      );
    }
  }

  static void validatePayment(Payment payment) {
    _requireValidDate(payment.paymentDate, fieldName: 'payment.paymentDate');
    if (!payment.amount.isFinite || payment.amount <= 0) {
      throw const FormatException(
        'payment.amount must be a finite positive number',
      );
    }
  }

  static void _requireValidDate(String value, {required String fieldName}) {
    try {
      final parsed = DateTime.parse(value);
      if (formatDate(parsed) != value) {
        throw FormatException('$fieldName must use YYYY-MM-DD format');
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw FormatException('$fieldName must use YYYY-MM-DD format');
    }
  }

  static void _requireValidTime(String value, {required String fieldName}) {
    final parts = value.split(':');
    if (parts.length != 2) {
      throw FormatException('$fieldName must use HH:mm format');
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        parts[0].length != 2 ||
        parts[1].length != 2) {
      throw FormatException('$fieldName must use HH:mm format');
    }
  }

  static bool _isEndAfterStart(String startTime, String endTime) {
    final start = _minutesOfDay(startTime);
    final end = _minutesOfDay(endTime);
    return end > start;
  }

  static int _minutesOfDay(String value) {
    final parts = value.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }
}
