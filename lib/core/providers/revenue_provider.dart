import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/constants.dart' show formatDate;
import 'attendance_provider.dart';
import 'fee_summary_provider.dart';

class RevenueData {
  final List<Map<String, dynamic>> monthlyReceivable; // [{month, totalFee}]
  final List<Map<String, dynamic>> monthlyReceived;   // [{month, totalReceived}]

  const RevenueData({
    required this.monthlyReceivable,
    required this.monthlyReceived,
  });
}

class RevenueNotifier extends AsyncNotifier<RevenueData> {
  @override
  Future<RevenueData> build() async {
    final now = DateTime.now();
    final from = formatDate(DateTime(now.year - 1, now.month, 1));
    final to = formatDate(DateTime(now.year, now.month + 1, 0));
    final attendanceDao = ref.read(attendanceDaoProvider);
    final paymentDao = ref.read(paymentDaoProvider);
    final receivable = await attendanceDao.getMonthlyRevenue(from, to);
    final received = await paymentDao.getMonthlyReceived(from, to);
    return RevenueData(
        monthlyReceivable: receivable, monthlyReceived: received);
  }
}

final revenueProvider =
    AsyncNotifierProvider<RevenueNotifier, RevenueData>(RevenueNotifier.new);
