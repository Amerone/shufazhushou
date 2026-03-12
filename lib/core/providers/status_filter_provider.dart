import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance.dart';
import 'attendance_provider.dart';
import 'statistics_period_provider.dart';

// null = 未筛选（显示全部）
final statusFilterProvider = StateProvider<String?>((ref) => null);

/// Watches [statusFilterProvider] and [statisticsPeriodProvider] to query
/// attendance records for a specific status in the current time range.
/// Returns empty list when no status is selected.
final filteredAttendanceProvider = FutureProvider<List<Attendance>>((ref) async {
  final status = ref.watch(statusFilterProvider);
  if (status == null) return [];

  final range = ref.watch(statisticsPeriodProvider);
  final dao = ref.read(attendanceDaoProvider);
  return dao.getByDateRangeAndStatus(range.from, range.to, status);
});
