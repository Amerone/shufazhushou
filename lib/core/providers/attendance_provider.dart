import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/constants.dart' show formatDate;
import '../database/dao/attendance_dao.dart';
import '../models/attendance.dart';
import 'database_provider.dart';

final attendanceDaoProvider = Provider<AttendanceDao>((ref) {
  return AttendanceDao(ref.watch(databaseProvider));
});

/// Shared cache for all attendance rows grouped by student id.
final allAttendanceByStudentProvider =
    FutureProvider<Map<String, List<Attendance>>>((ref) {
      return ref.watch(attendanceDaoProvider).getAllGroupedByStudent();
    });

// Currently selected day.
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Month currently visible in calendar.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// All attendance rows of the selected month.
class MonthAttendanceNotifier extends AsyncNotifier<List<Attendance>> {
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
      () => ref.read(attendanceDaoProvider).getByDateRange(from, to),
    );
  }
}

final attendanceProvider =
    AsyncNotifierProvider<MonthAttendanceNotifier, List<Attendance>>(
      MonthAttendanceNotifier.new,
    );

/// Cache monthly records grouped by date to avoid rebuilding this map repeatedly.
final monthAttendanceByDateProvider = Provider<Map<String, List<Attendance>>>((
  ref,
) {
  final monthRecords = ref.watch(attendanceProvider).valueOrNull;
  if (monthRecords == null || monthRecords.isEmpty) {
    return const <String, List<Attendance>>{};
  }

  final grouped = <String, List<Attendance>>{};
  for (final record in monthRecords) {
    (grouped[record.date] ??= <Attendance>[]).add(record);
  }
  return grouped;
});

enum AttendanceDaySummary { normal, mixed, absent }

/// Cache day-level status summaries for calendar markers.
final monthAttendanceDaySummaryProvider =
    Provider<Map<String, AttendanceDaySummary>>((ref) {
      final recordsByDate = ref.watch(monthAttendanceByDateProvider);
      if (recordsByDate.isEmpty) {
        return const <String, AttendanceDaySummary>{};
      }

      final summaryByDate = <String, AttendanceDaySummary>{};
      for (final entry in recordsByDate.entries) {
        var hasAbsent = false;
        var hasPresentLike = false;

        for (final record in entry.value) {
          final status = record.status;
          if (status == 'absent') {
            hasAbsent = true;
          }
          if (status == 'present' || status == 'late') {
            hasPresentLike = true;
          }

          if (hasAbsent && hasPresentLike) {
            break;
          }
        }

        if (hasAbsent && hasPresentLike) {
          summaryByDate[entry.key] = AttendanceDaySummary.mixed;
        } else if (hasAbsent) {
          summaryByDate[entry.key] = AttendanceDaySummary.absent;
        } else {
          summaryByDate[entry.key] = AttendanceDaySummary.normal;
        }
      }

      return summaryByDate;
    });

List<Attendance> _sortedByStartTime(List<Attendance> records) {
  if (records.length < 2) {
    return records;
  }

  final sorted = List<Attendance>.from(records);
  sorted.sort((a, b) {
    final startCompare = a.startTime.compareTo(b.startTime);
    if (startCompare != 0) {
      return startCompare;
    }
    return a.createdAt.compareTo(b.createdAt);
  });
  return sorted;
}

// Attendance rows for the selected day.
final selectedDateAttendanceProvider = FutureProvider<List<Attendance>>((
  ref,
) async {
  final date = ref.watch(selectedDateProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final isSameMonth =
      date.year == selectedMonth.year && date.month == selectedMonth.month;

  if (!isSameMonth) {
    final records = await ref
        .read(attendanceDaoProvider)
        .getByDate(formatDate(date));
    return _sortedByStartTime(records);
  }

  final dateKey = formatDate(date);
  final monthRecords = await ref.watch(attendanceProvider.future);
  return _sortedByStartTime([
    for (final record in monthRecords)
      if (record.date == dateKey) record,
  ]);
});
