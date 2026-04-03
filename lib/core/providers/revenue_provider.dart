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
    final receivable = await attendanceDao.getMonthlyRevenue(
      range.from,
      range.to,
    );
    final received = await paymentDao.getMonthlyReceived(range.from, range.to);
    return RevenueData(
      monthlyReceivable: receivable,
      monthlyReceived: received,
    );
  }
}

final revenueProvider = AsyncNotifierProvider<RevenueNotifier, RevenueData>(
  RevenueNotifier.new,
);
