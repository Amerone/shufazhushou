import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/dao/payment_dao.dart';
import '../utils/fee_calculator.dart';
import 'attendance_provider.dart';
import 'database_provider.dart';

final paymentDaoProvider = Provider(
  (ref) => PaymentDao(ref.watch(databaseProvider)),
);

/// Shared cache for all paid amounts grouped by student id.
final allPaymentsByStudentProvider = FutureProvider<Map<String, double>>((ref) {
  return ref.watch(paymentDaoProvider).getTotalByAllStudents();
});

class FeeSummaryNotifier
    extends FamilyAsyncNotifier<StudentFeeSummary, FeeSummaryParams> {
  @override
  Future<StudentFeeSummary> build(FeeSummaryParams arg) {
    return FeeCalculator.calcSummary(
      arg.studentId,
      ref.watch(attendanceDaoProvider),
      ref.watch(paymentDaoProvider),
      from: arg.from,
      to: arg.to,
    );
  }
}

final feeSummaryProvider =
    AsyncNotifierProviderFamily<
      FeeSummaryNotifier,
      StudentFeeSummary,
      FeeSummaryParams
    >(FeeSummaryNotifier.new);
