import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/constants.dart' show formatDate;
import '../database/dao/attendance_dao.dart';
import '../models/attendance.dart';
import 'database_provider.dart';

final attendanceDaoProvider = Provider<AttendanceDao>((ref) {
  return AttendanceDao(ref.watch(databaseProvider));
});

// 选中日期
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// 当前查看月份
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// 当月全量出勤记录（供日历角标聚合）
class MonthAttendanceNotifier
    extends AsyncNotifier<List<Attendance>> {
  @override
  Future<List<Attendance>> build() async {
    final month = ref.watch(selectedMonthProvider);
    final from = formatDate(DateTime(month.year, month.month, 1));
    final to = formatDate(DateTime(month.year, month.month + 1, 0));
    return ref.read(attendanceDaoProvider).getByDateRange(from, to);
  }

  Future<void> reload() async {
    final month = ref.read(selectedMonthProvider);
    final from = formatDate(DateTime(month.year, month.month, 1));
    final to = formatDate(DateTime(month.year, month.month + 1, 0));
    state = await AsyncValue.guard(
        () => ref.read(attendanceDaoProvider).getByDateRange(from, to));
  }
}

final attendanceProvider =
    AsyncNotifierProvider<MonthAttendanceNotifier, List<Attendance>>(
        MonthAttendanceNotifier.new);

// 选中日期的出勤列表
final selectedDateAttendanceProvider =
    FutureProvider<List<Attendance>>((ref) async {
  final date = ref.watch(selectedDateProvider);
  return ref.read(attendanceDaoProvider).getByDate(formatDate(date));
});
