import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../shared/constants.dart' show formatDate;
import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/attendance_calendar.dart';
import '../widgets/attendance_list.dart';
import '../widgets/quick_entry_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final monthKey = DateFormat('yyyy-MM', 'zh_CN').format(selectedMonth);
    final monthCount = asyncRecords.valueOrNull
            ?.where((record) => record.date.startsWith(monthKey))
            .length ??
        0;
    final totalCount = asyncRecords.valueOrNull?.length ?? 0;
    final headerSubtitle = isToday ? '$monthLabel · 今天已记录 $count 条' : '$monthLabel · $dateLabel';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '笔墨课堂总览',
              subtitle: headerSubtitle,
              trailing: _TodayAction(
                onPressed: () {
                  final now = DateTime.now();
                  ref.read(selectedDateProvider.notifier).state = now;
                  ref.read(selectedMonthProvider.notifier).state = DateTime(now.year, now.month);
                  ref.read(attendanceProvider.notifier).reload();
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: kSealRed,
                onRefresh: () async {
                  ref.read(attendanceProvider.notifier).reload();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _DateSummaryCard(
                          monthLabel: monthLabel,
                          dateLabel: dateLabel,
                          summaryText: summaryText,
                          dayCount: count,
                          monthCount: monthCount,
                          totalCount: totalCount,
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
                        child: GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Builder(
                            builder: (context) {
                              final theme = Theme.of(context);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        sectionTitle,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: kPrimaryBlue.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '$count 条',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: kPrimaryBlue,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const AttendanceList(),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
  final String monthLabel;
  final String dateLabel;
  final String summaryText;
  final int dayCount;
  final int monthCount;
  final int totalCount;

  const _DateSummaryCard({
    required this.monthLabel,
    required this.dateLabel,
    required this.summaryText,
    required this.dayCount,
    required this.monthCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: kSealRed.withValues(alpha: 0.1),
                  border: Border.all(color: kSealRed.withValues(alpha: 0.2), width: 1),
                ),
                child: const Icon(Icons.auto_stories_outlined, size: 22, color: kSealRed),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          dateLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
                          ),
                          child: Text(monthLabel, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summaryText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kInkSecondary.withValues(alpha: 0.8),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;
              final itemWidth = compact
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 24) / 3;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '当日记录',
                      value: '$dayCount',
                      color: kSealRed,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '本月课次',
                      value: '$monthCount',
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '累计记录',
                      value: '$totalCount',
                      color: kGreen,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TodayAction extends StatelessWidget {
  final VoidCallback onPressed;

  const _TodayAction({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryBlue,
        backgroundColor: Colors.white.withValues(alpha: 0.58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: kInkSecondary.withValues(alpha: 0.18)),
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.today_outlined, size: 18),
      label: const Text('回到今日'),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'NotoSansSC',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
