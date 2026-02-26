import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'attendance_provider.dart';
import 'statistics_period_provider.dart';

class MetricsData {
  final double totalFee;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int activeStudentCount;

  const MetricsData({
    required this.totalFee,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.activeStudentCount,
  });
}

class MetricsNotifier extends AsyncNotifier<MetricsData> {
  @override
  Future<MetricsData> build() async {
    final range = ref.watch(statisticsPeriodProvider);
    final attendanceDao = ref.read(attendanceDaoProvider);
    final m = await attendanceDao.getMetrics(range.from, range.to);
    return MetricsData(
      totalFee: (m['totalFee'] as num?)?.toDouble() ?? 0,
      presentCount: (m['presentCount'] as num?)?.toInt() ?? 0,
      lateCount: (m['lateCount'] as num?)?.toInt() ?? 0,
      absentCount: (m['absentCount'] as num?)?.toInt() ?? 0,
      activeStudentCount: (m['activeStudentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

final metricsProvider =
    AsyncNotifierProvider<MetricsNotifier, MetricsData>(MetricsNotifier.new);
