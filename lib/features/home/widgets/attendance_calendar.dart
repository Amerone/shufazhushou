import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/models/attendance.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../shared/constants.dart' show formatDate;
import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';

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

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '上课日历',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '点击日期可查看当天记录，色条用于提示出勤状态。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _LegendChip(label: '正常', color: kGreen),
              _LegendChip(label: '含缺勤', color: kOrange),
              _LegendChip(label: '缺勤', color: kRed),
            ],
          ),
          const SizedBox(height: 10),
          TableCalendar(
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
              cellMargin: const EdgeInsets.all(4),
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
                    width: 18,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
