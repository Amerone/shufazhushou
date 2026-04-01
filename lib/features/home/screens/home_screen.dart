import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/home_workbench_provider.dart';
import '../../../shared/constants.dart' show formatDate;
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/attendance_calendar.dart';
import '../widgets/attendance_list.dart';
import '../widgets/home_workbench_panel.dart';
import '../widgets/quick_entry_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final asyncRecords = ref.watch(attendanceProvider);
    final workbenchTasks = ref.watch(homeWorkbenchProvider);
    final today = DateTime.now();

    final dateStr = formatDate(selectedDate);
    final dayCount =
        asyncRecords.valueOrNull
            ?.where((record) => record.date == dateStr)
            .length ??
        0;
    final monthKey = DateFormat('yyyy-MM', 'zh_CN').format(selectedMonth);
    final monthCount =
        asyncRecords.valueOrNull
            ?.where((record) => record.date.startsWith(monthKey))
            .length ??
        0;
    final pendingTaskCount = workbenchTasks.valueOrNull?.length;

    final monthLabel = DateFormat('yyyy年M月', 'zh_CN').format(selectedMonth);
    final dateLabel = DateFormat('M月d日 EEEE', 'zh_CN').format(selectedDate);
    final isToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
    final sectionTitle = isToday ? '今日记录' : '$dateLabel 记录';
    final headerSubtitle = isToday ? '先记课，再处理待办。' : '$dateLabel 已选中，可继续核对当日记录。';

    final homeTheme = theme.copyWith(
      splashColor: kPrimaryBlue.withValues(alpha: 0.08),
      highlightColor: kPrimaryBlue.withValues(alpha: 0.04),
      hoverColor: kPrimaryBlue.withValues(alpha: 0.03),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Theme(
        data: homeTheme,
        child: InkWashBackground(
          child: Column(
            children: [
              PageHeader(
                title: '今日工作台',
                subtitle: headerSubtitle,
                trailing: _TodayAction(
                  onPressed: () {
                    unawaited(InteractionFeedback.selection(context));
                    ref.read(selectedDateProvider.notifier).state = today;
                    ref.read(selectedMonthProvider.notifier).state = DateTime(
                      today.year,
                      today.month,
                    );
                    ref.read(attendanceProvider.notifier).reload();
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: kSealRed,
                  edgeOffset: 20,
                  displacement: 28,
                  onRefresh: () async {
                    ref.read(attendanceProvider.notifier).reload();
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _HomeFocusCard(
                            monthLabel: monthLabel,
                            dateLabel: dateLabel,
                            dayCount: dayCount,
                            monthCount: monthCount,
                            taskCount: pendingTaskCount,
                            isToday: isToday,
                            onQuickEntry: () => _openQuickEntrySheet(context),
                            onOpenStudents: () async {
                              await InteractionFeedback.pageTurn(context);
                              if (!context.mounted) return;
                              context.go('/students');
                            },
                            onOpenStatistics: () async {
                              await InteractionFeedback.pageTurn(context);
                              if (!context.mounted) return;
                              context.go('/statistics');
                            },
                          ),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                        sliver: SliverToBoxAdapter(child: HomeWorkbenchPanel()),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _SectionTitleRow(
                            title: sectionTitle,
                            countText: '$dayCount 条',
                            color: kSealRed,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: GlassCard(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '按时间顺序查看与调整当日记录',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const AttendanceList(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _SectionTitleRow(
                            title: '本月课历',
                            countText: '$monthCount 次',
                            color: kPrimaryBlue,
                          ),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 120),
                        sliver: SliverToBoxAdapter(child: AttendanceCalendar()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 80,
        ),
        child: _QuickEntryAction(
          onPressed: () => _openQuickEntrySheet(context),
        ),
      ),
    );
  }
}

Future<void> _openQuickEntrySheet(BuildContext context) async {
  unawaited(InteractionFeedback.selection(context));
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const QuickEntrySheet(),
  );
}

class _HomeFocusCard extends StatelessWidget {
  final String monthLabel;
  final String dateLabel;
  final int dayCount;
  final int monthCount;
  final int? taskCount;
  final bool isToday;
  final VoidCallback onQuickEntry;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenStatistics;

  const _HomeFocusCard({
    required this.monthLabel,
    required this.dateLabel,
    required this.dayCount,
    required this.monthCount,
    required this.taskCount,
    required this.isToday,
    required this.onQuickEntry,
    required this.onOpenStudents,
    required this.onOpenStatistics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount = taskCount ?? 0;
    final nextActionText = dayCount == 0
        ? '下一步：先记录今天第一节课。'
        : pendingCount > 0
        ? '下一步：处理 $pendingCount 项待办，避免任务堆积。'
        : '下一步：核对记录后，可查看本月课历安排。';

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: kInkSecondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  monthLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kSealRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isToday ? '今日优先' : '当前日期',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kSealRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            dateLabel,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextActionText,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 3 : 2;
              final itemWidth =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '今日记录',
                      value: '$dayCount',
                      hint: '当前日期',
                      color: kSealRed,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '本月课次',
                      value: '$monthCount',
                      hint: monthLabel,
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '待办',
                      value: taskCount?.toString() ?? '—',
                      hint: taskCount == null ? '加载中' : '优先处理',
                      color: kOrange,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final primaryWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              final secondaryWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: primaryWidth,
                    child: FilledButton.icon(
                      onPressed: onQuickEntry,
                      style: FilledButton.styleFrom(
                        backgroundColor: kSealRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.brush_outlined),
                      label: const Text('立即记课'),
                    ),
                  ),
                  SizedBox(
                    width: secondaryWidth,
                    child: OutlinedButton.icon(
                      onPressed: onOpenStatistics,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.auto_graph_outlined),
                      label: Text((taskCount ?? 0) > 0 ? '处理待办' : '经营统计'),
                    ),
                  ),
                  SizedBox(
                    width: secondaryWidth,
                    child: OutlinedButton.icon(
                      onPressed: onOpenStudents,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.people_alt_outlined),
                      label: const Text('学生档案'),
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

class _SectionTitleRow extends StatelessWidget {
  final String title;
  final String countText;
  final Color color;

  const _SectionTitleRow({
    required this.title,
    required this.countText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Text(
            countText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
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
        overlayColor: kSealRed.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: kInkSecondary.withValues(alpha: 0.18)),
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.today_outlined, size: 18),
      label: const Text('回到今天'),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: kInkSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'NotoSansSC',
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(hint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _QuickEntryAction extends StatelessWidget {
  final VoidCallback onPressed;

  const _QuickEntryAction({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kSealRed.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'home-quick-entry',
        onPressed: onPressed,
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: kSealRed,
        foregroundColor: Colors.white,
        splashColor: Colors.white.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        icon: const Icon(Icons.brush_outlined),
        label: const Text(
          '立即记课',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      ),
    );
  }
}
