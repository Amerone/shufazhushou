import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/models/attendance.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../shared/constants.dart' show formatDate;
import '../../../shared/theme.dart';

class AttendanceCalendar extends ConsumerStatefulWidget {
  const AttendanceCalendar({super.key});

  @override
  ConsumerState<AttendanceCalendar> createState() => _AttendanceCalendarState();
}

class _AttendanceCalendarState extends ConsumerState<AttendanceCalendar> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = ref.read(selectedDateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedDateProvider);
    final asyncRecords = ref.watch(attendanceProvider);

    final badges = <String, Color>{};
    asyncRecords.whenData((records) {
      final byDate = <String, List<Attendance>>{};
      for (final r in records) {
        byDate.putIfAbsent(r.date, () => []).add(r);
      }

      for (final entry in byDate.entries) {
        final statuses = entry.value.map((r) => r.status).toSet();
        final hasAbsent = statuses.contains('absent');
        final hasPresent = statuses.contains('present') || statuses.contains('late');

        if (hasAbsent && hasPresent) {
          badges[entry.key] = kOrange;
        } else if (hasAbsent) {
          badges[entry.key] = kRed;
        } else {
          badges[entry.key] = kGreen;
        }
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: TableCalendar(
          locale: 'zh_CN',
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(d, selectedDate),
          onDaySelected: (selected, focused) {
            ref.read(selectedDateProvider.notifier).state = selected;
            setState(() => _focusedDay = focused);
          },
          onPageChanged: (focused) {
            setState(() => _focusedDay = focused);
            ref.read(selectedDateProvider.notifier).state =
                DateTime(focused.year, focused.month);
            ref.read(selectedMonthProvider.notifier).state =
                DateTime(focused.year, focused.month);
          },
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: theme.textTheme.titleMedium ?? const TextStyle(),
            leftChevronIcon: const Icon(Icons.chevron_left, color: kInkSecondary),
            rightChevronIcon: const Icon(Icons.chevron_right, color: kInkSecondary),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: theme.textTheme.bodySmall ?? const TextStyle(),
            weekendStyle: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(color: kRed),
          ),
          calendarStyle: CalendarStyle(
            defaultTextStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
            weekendTextStyle: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(color: kRed),
            selectedDecoration: const BoxDecoration(
              color: kPrimaryBlue,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: kSealRed.withValues(alpha: 0.16),
              border: Border.all(color: kSealRed.withValues(alpha: 0.4)),
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(shape: BoxShape.circle),
            outsideTextStyle: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
              color: kInkSecondary.withValues(alpha: 0.45),
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              final key = formatDate(day);
              final color = badges[key];
              if (color == null) return null;

              return Positioned(
                bottom: 5,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
