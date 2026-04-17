import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'attendance_provider.dart';
import 'fee_summary_provider.dart';
import 'statistics_period_provider.dart';

class RevenueData {
  final List<Map<String, dynamic>> monthlyReceivable; // [{month, totalFee}]
  final List<Map<String, dynamic>> monthlyReceived; // [{month, totalReceived}]

  const RevenueData({
    required this.monthlyReceivable,
    required this.monthlyReceived,
  });
}

class RevenueNotifier extends AsyncNotifier<RevenueData> {
  @override
  Future<RevenueData> build() async {
    final range = ref.watch(statisticsPeriodProvider);
    final attendanceDao = ref.read(attendanceDaoProvider);
    final paymentDao = ref.read(paymentDaoProvider);
    final receivableFuture = attendanceDao.getMonthlyRevenue(
      range.from,
      range.to,
    );
    final receivedFuture = paymentDao.getMonthlyReceived(range.from, range.to);
    final results = await Future.wait<Object?>([
      receivableFuture,
      receivedFuture,
    ]);
    final receivable = results[0] as List<Map<String, dynamic>>;
    final received = results[1] as List<Map<String, dynamic>>;
    return RevenueData(
      monthlyReceivable: receivable,
      monthlyReceived: received,
    );
  }
}

final revenueProvider = AsyncNotifierProvider<RevenueNotifier, RevenueData>(
  RevenueNotifier.new,
);
