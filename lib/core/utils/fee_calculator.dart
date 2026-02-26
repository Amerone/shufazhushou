import '../database/dao/attendance_dao.dart';
import '../database/dao/payment_dao.dart';
import '../../shared/constants.dart';

class StudentFeeSummary {
  final double totalReceivable;
  final double totalReceived;
  final double balance; // 正=预存，负=欠费

  const StudentFeeSummary({
    required this.totalReceivable,
    required this.totalReceived,
    required this.balance,
  });
}

class FeeSummaryParams {
  final String studentId;
  final String? from;
  final String? to;

  const FeeSummaryParams(this.studentId, {this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is FeeSummaryParams &&
      other.studentId == studentId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(studentId, from, to);
}

class FeeCalculator {
  static double calcFee(AttendanceStatus status, double priceSnapshot) {
    switch (status) {
      case AttendanceStatus.present:
      case AttendanceStatus.late:
        return priceSnapshot;
      default:
        return 0;
    }
  }

  static Future<StudentFeeSummary> calcSummary(
    String studentId,
    AttendanceDao attendanceDao,
    PaymentDao paymentDao, {
    String? from,
    String? to,
  }) async {
    final records =
        await attendanceDao.getByStudentAndDateRange(studentId, from, to);
    final totalReceivable =
        records.fold<double>(0, (sum, r) => sum + r.feeAmount);
    final totalReceived =
        await paymentDao.getTotalByStudentAndDateRange(studentId, from, to);
    return StudentFeeSummary(
      totalReceivable: totalReceivable,
      totalReceived: totalReceived,
      balance: totalReceived - totalReceivable,
    );
  }
}
