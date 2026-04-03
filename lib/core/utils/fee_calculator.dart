import '../../shared/constants.dart';
import '../database/dao/attendance_dao.dart';
import '../database/dao/payment_dao.dart';

class StudentFeeSummary {
  final double totalReceivable;
  final double totalReceived;
  final double openingBalance;
  final double periodNetChange;
  final double balance;

  const StudentFeeSummary({
    required this.totalReceivable,
    required this.totalReceived,
    required this.openingBalance,
    required this.periodNetChange,
    required this.balance,
  });
}

enum LedgerAmountState { negative, neutral, positive }

LedgerAmountState resolveLedgerAmountState(double amount) {
  if (amount < 0) {
    return LedgerAmountState.negative;
  }
  if (amount > 0) {
    return LedgerAmountState.positive;
  }
  return LedgerAmountState.neutral;
}

enum LedgerBalanceState { debt, settled, surplus }

class StudentLedgerView {
  final double balance;
  final double pricePerClass;
  final bool hasBalanceHistory;

  const StudentLedgerView({
    required this.balance,
    required this.pricePerClass,
    required this.hasBalanceHistory,
  });

  factory StudentLedgerView.fromTotals({
    required double totalReceivable,
    required double totalReceived,
    required double pricePerClass,
  }) {
    return StudentLedgerView(
      balance: totalReceived - totalReceivable,
      pricePerClass: pricePerClass,
      hasBalanceHistory: totalReceivable > 0 || totalReceived > 0,
    );
  }

  factory StudentLedgerView.fromSummary(
    StudentFeeSummary summary, {
    required double pricePerClass,
  }) {
    return StudentLedgerView(
      balance: summary.balance,
      pricePerClass: pricePerClass,
      hasBalanceHistory:
          summary.totalReceivable > 0 ||
          summary.totalReceived > 0 ||
          summary.openingBalance != 0,
    );
  }

  bool get isDebt => balance < 0;

  LedgerBalanceState get balanceState {
    if (balance < 0) {
      return LedgerBalanceState.debt;
    }
    if (balance > 0) {
      return LedgerBalanceState.surplus;
    }
    return LedgerBalanceState.settled;
  }

  String get balanceStatusLabel {
    switch (balanceState) {
      case LedgerBalanceState.debt:
        return '待缴';
      case LedgerBalanceState.settled:
        return '结清';
      case LedgerBalanceState.surplus:
        return '结余';
    }
  }

  String get currentBalanceLabel {
    switch (balanceState) {
      case LedgerBalanceState.debt:
        return '截至当前待缴';
      case LedgerBalanceState.settled:
        return '截至当前余额';
      case LedgerBalanceState.surplus:
        return '截至当前结余';
    }
  }

  String get totalBalanceLabel {
    switch (balanceState) {
      case LedgerBalanceState.debt:
        return '总待缴';
      case LedgerBalanceState.settled:
        return '总余额';
      case LedgerBalanceState.surplus:
        return '总结余';
    }
  }

  double? get remainingLessons =>
      pricePerClass > 0 ? balance / pricePerClass : null;

  bool get hitsRenewalAmountThreshold =>
      balance >= 0 && balance < kBalanceAlertAmountThreshold;

  bool get hitsRenewalLessonThreshold {
    final lessons = remainingLessons;
    return lessons != null &&
        lessons >= 0 &&
        lessons < kBalanceAlertLessonThreshold;
  }

  bool get needsRenewalAttention =>
      hasBalanceHistory &&
      (hitsRenewalAmountThreshold || hitsRenewalLessonThreshold);

  bool get needsPaymentAttention => isDebt;
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
    final totalReceivable = await attendanceDao
        .getTotalFeeByStudentAndDateRange(studentId, from, to);
    final totalReceived = await paymentDao.getTotalByStudentAndDateRange(
      studentId,
      from,
      to,
    );
    final openingBalance = await _calcOpeningBalance(
      studentId,
      attendanceDao,
      paymentDao,
      from,
    );
    final periodNetChange = totalReceived - totalReceivable;

    return StudentFeeSummary(
      totalReceivable: totalReceivable,
      totalReceived: totalReceived,
      openingBalance: openingBalance,
      periodNetChange: periodNetChange,
      balance: openingBalance + periodNetChange,
    );
  }

  static Future<double> _calcOpeningBalance(
    String studentId,
    AttendanceDao attendanceDao,
    PaymentDao paymentDao,
    String? from,
  ) async {
    if (from == null) {
      return 0;
    }

    final previousDate = formatDate(
      DateTime.parse(from).subtract(const Duration(days: 1)),
    );
    final receivableBeforeFrom = await attendanceDao
        .getTotalFeeByStudentAndDateRange(studentId, null, previousDate);
    final receivedBeforeFrom = await paymentDao.getTotalByStudentAndDateRange(
      studentId,
      null,
      previousDate,
    );
    return receivedBeforeFrom - receivableBeforeFrom;
  }
}
