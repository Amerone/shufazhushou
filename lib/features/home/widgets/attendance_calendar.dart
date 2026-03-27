import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/models/attendance.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../shared/constants.dart' show formatDate;
import '../../../shared/theme.dart';
import '../../../shared/widgets/brush_stroke_divider.dart';
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '出勤月历',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const BrushStrokeDivider(
                      width: 96,
                      height: 12,
                      color: kPrimaryBlue,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '短笔触标识每日整体状态，点击日期即可翻看对应课堂记录。',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: kSealRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _LegendChip(label: '正常', color: kGreen),
              _LegendChip(label: '含缺勤', color: kOrange),
              _LegendChip(label: '缺勤', color: kRed),
            ],
          ),
          const SizedBox(height: 14),
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
              titleTextStyle: (theme.textTheme.titleMedium ?? const TextStyle())
                  .copyWith(fontWeight: FontWeight.w700),
              leftChevronIcon: const Icon(Icons.chevron_left, color: kInkSecondary),
              rightChevronIcon: const Icon(Icons.chevron_right, color: kInkSecondary),
              headerPadding: const EdgeInsets.only(bottom: 12),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                color: kInkSecondary.withValues(alpha: 0.9),
              ),
              weekendStyle: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                color: kRed,
              ),
            ),
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              defaultTextStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
              weekendTextStyle:
                  (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                color: kRed,
              ),
              selectedDecoration: BoxDecoration(
                color: kPrimaryBlue.withValues(alpha: 0.94),
                border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.18)),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: kSealRed.withValues(alpha: 0.14),
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
                  bottom: 7,
                  child: BrushStrokeDivider(
                    width: 18,
                    height: 6,
                    color: color,
                    alignment: Alignment.center,
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
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrushStrokeDivider(
            width: 18,
            height: 8,
            color: color,
            alignment: Alignment.center,
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
