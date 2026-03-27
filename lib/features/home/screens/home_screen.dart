import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../shared/constants.dart' show formatDate;
import '../../../shared/theme.dart';
import '../../../shared/widgets/brush_stroke_divider.dart';
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
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final asyncRecords = ref.watch(attendanceProvider);
    final today = DateTime.now();

    final dateStr = formatDate(selectedDate);
    final count = asyncRecords.valueOrNull?.where((r) => r.date == dateStr).length ?? 0;

    final monthLabel = DateFormat('yyyy年M月', 'zh_CN').format(selectedMonth);
    final dateLabel = DateFormat('M月d日 EEEE', 'zh_CN').format(selectedDate);
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
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
                title: '笔墨课堂总览',
                subtitle: headerSubtitle,
                trailing: _TodayAction(
                  onPressed: () {
                    ref.read(selectedDateProvider.notifier).state = today;
                    ref.read(selectedMonthProvider.notifier).state =
                        DateTime(today.year, today.month);
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
                          child: _DateSummaryCard(
                            monthLabel: monthLabel,
                            dateLabel: dateLabel,
                            summaryText: summaryText,
                            dayCount: count,
                            monthCount: monthCount,
                            totalCount: totalCount,
                            isToday: isToday,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _SectionLead(
                            eyebrow: '课历',
                            title: '翻阅本月出勤笔记',
                            subtitle: '点选具体日期即可切换当天记录，色条会提示整天的整体出勤状态。',
                            badgeText: '$monthCount 次',
                            badgeColor: kPrimaryBlue,
                          ),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                        sliver: SliverToBoxAdapter(child: AttendanceCalendar()),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _SectionLead(
                            eyebrow: isToday ? '札记' : '选日',
                            title: sectionTitle,
                            subtitle: isToday
                                ? '按课时顺序整理今日记录，轻触卡片可直接补改或核对细节。'
                                : '切换日期后，这里会按时间顺序展开当日的全部课时记录。',
                            badgeText: '$count 条',
                            badgeColor: kSealRed,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                        sliver: SliverToBoxAdapter(
                          child: GlassCard(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sectionTitle,
                                            style: theme.textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const BrushStrokeDivider(
                                            width: 128,
                                            height: 12,
                                            color: kPrimaryBlue,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kSealRed.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: kSealRed.withValues(alpha: 0.16),
                                        ),
                                      ),
                                      child: Text(
                                        '$count 条',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: kSealRed,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isToday ? '今日已整理的课时按时间自然展开。' : '按当前选中日期查看对应记录。',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const AttendanceList(),
                              ],
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
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 80,
        ),
        child: _QuickEntryAction(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const QuickEntrySheet(),
          ),
        ),
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
  final bool isToday;

  const _DateSummaryCard({
    required this.monthLabel,
    required this.dateLabel,
    required this.summaryText,
    required this.dayCount,
    required this.monthCount,
    required this.totalCount,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -14,
            child: IgnorePointer(
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(132),
                  gradient: RadialGradient(
                    colors: [
                      kSealRed.withValues(alpha: 0.12),
                      kSealRed.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.52),
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
                        const SizedBox(height: 16),
                        Text(
                          isToday ? '今日课堂札记' : '当日课时摘录',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kInkSecondary.withValues(alpha: 0.86),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateLabel,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFamily: 'MaShanZheng',
                            fontWeight: FontWeight.w600,
                            fontSize: 30,
                            height: 1.2,
                            color: const Color(0xFF26221D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summaryText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: kInkSecondary.withValues(alpha: 0.9),
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: kSealRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: kSealRed.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isToday ? '今' : '选',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kSealRed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '札记',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kSealRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const BrushStrokeDivider(
                width: 156,
                height: 12,
                color: kPrimaryBlue,
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 460;
                  final itemWidth = compact
                      ? (constraints.maxWidth - 14) / 2
                      : (constraints.maxWidth - 28) / 3;

                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _SummaryMetric(
                          label: '当日记录',
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
                          hint: '本月累计',
                          color: kPrimaryBlue,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _SummaryMetric(
                          label: '累计记录',
                          value: '$totalCount',
                          hint: '历次沉淀',
                          color: kGreen,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLead extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;

  const _SectionLead({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kInkSecondary.withValues(alpha: 0.88),
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              BrushStrokeDivider(
                width: title.length > 8 ? 128 : 112,
                height: 12,
                color: badgeColor,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: badgeColor.withValues(alpha: 0.14)),
          ),
          child: Text(
            badgeText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: badgeColor,
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
      label: const Text('回到今日'),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrushStrokeDivider(
            width: 44,
            height: 10,
            color: color,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: kInkSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
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

  const _QuickEntryAction({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kSealRed.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
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
          '快速记课',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      ),
    );
  }
}
