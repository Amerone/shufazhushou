import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../shared/constants.dart' show formatDate;
import '../../../shared/theme.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../widgets/attendance_calendar.dart';
import '../widgets/attendance_list.dart';
import '../widgets/quick_entry_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final asyncRecords = ref.watch(attendanceProvider);

    final dateStr = formatDate(selectedDate);
    final count = asyncRecords.valueOrNull?.where((r) => r.date == dateStr).length ?? 0;

    final monthLabel = DateFormat('yyyy年M月', 'zh_CN').format(selectedMonth);
    final dateLabel = DateFormat('M月d日 EEEE', 'zh_CN').format(selectedDate);
    final isToday = selectedDate.year == DateTime.now().year &&
        selectedDate.month == DateTime.now().month &&
        selectedDate.day == DateTime.now().day;
    final sectionTitle = isToday ? '今日记录' : '$dateLabel 记录';
    final summaryText = isToday
        ? '今日共 $count 条出勤记录'
        : '当日共 $count 条出勤记录';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(monthLabel),
        actions: [
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              ref.read(selectedDateProvider.notifier).state = now;
              ref.read(selectedMonthProvider.notifier).state =
                  DateTime(now.year, now.month);
              ref.read(attendanceProvider.notifier).reload();
            },
            child: const Text('今日'),
          ),
        ],
      ),
      body: InkWashBackground(
        child: RefreshIndicator(
          color: kSealRed,
          onRefresh: () async {
            ref.read(attendanceProvider.notifier).reload();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _DateSummaryCard(
                    dateLabel: dateLabel,
                    summaryText: summaryText,
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(child: AttendanceCalendar()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      const AttendanceList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const QuickEntrySheet(),
        ),
        icon: const Icon(Icons.brush_outlined),
        label: const Text('快速记课'),
      ),
    );
  }
}

class _DateSummaryCard extends StatelessWidget {
  final String dateLabel;
  final String summaryText;
  const _DateSummaryCard({required this.dateLabel, required this.summaryText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: kSealRed.withValues(alpha: 0.12),
              border: Border.all(color: kSealRed.withValues(alpha: 0.3), width: 0.8),
            ),
            child: const Icon(Icons.auto_stories_outlined, size: 19, color: kSealRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(summaryText, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
