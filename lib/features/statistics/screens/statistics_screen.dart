import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/student.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/statistics_period_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/excel_exporter.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/contribution_chart.dart';
import '../widgets/data_insight_card.dart';
import '../widgets/insight_list.dart';
import '../widgets/metrics_grid.dart';
import '../widgets/revenue_chart.dart';
import '../widgets/time_heatmap.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(statisticsPeriodProvider);
    final periodLabel = switch (range.period) {
      StatisticsPeriod.week => '本周',
      StatisticsPeriod.month => '本月',
      StatisticsPeriod.year => '本年',
    };
    final periodDescription = switch (range.period) {
      StatisticsPeriod.week => '聚焦本周排课密度和即时收入表现。',
      StatisticsPeriod.month => '查看本月经营节奏、贡献结构与提醒。',
      StatisticsPeriod.year => '回看全年课程累计和营收趋势。',
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            const PageHeader(
              title: '经营统计',
              subtitle: '查看课时收入、出勤结构和当前周期提醒。',
            ),
            Expanded(
              child: RefreshIndicator(
                color: kSealRed,
                onRefresh: () async {
                  invalidateStatistics(ref);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                  children: [
                    _StatisticsOverviewCard(
                      range: range,
                      periodLabel: periodLabel,
                      periodDescription: periodDescription,
                      onExport: () => _exportAttendance(context, ref),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle(
                      title: '核心指标',
                      subtitle: '收入、出勤和活跃人数会跟随顶部周期切换自动刷新。',
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: const RepaintBoundary(child: MetricsGrid()),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '收入走势',
                      subtitle: '观察当前周期内的进账波动，及时识别高峰与空档。',
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: const RepaintBoundary(child: RevenueChart()),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '学生贡献',
                      subtitle: '对比学员在收入和到课上的贡献度，便于安排回访与续费。',
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: const RepaintBoundary(child: ContributionChart()),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '状态分布',
                      subtitle: '查看出勤状态占比，并快速定位异常记录。',
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          RepaintBoundary(child: StatusPieChart()),
                          SizedBox(height: 8),
                          StatusFilteredList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '上课热力',
                      subtitle: '识别常见上课时段，为排课和招生沟通提供参考。',
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: const RepaintBoundary(child: TimeHeatmap()),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: '经营提醒',
                      subtitle: '聚焦当前周期内需要跟进的续费、流失与排课信号。',
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: const InsightList(),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: 'AI 经营洞察',
                      subtitle: '基于当前周期核心数据生成经营分析和可执行建议。',
                    ),
                    const SizedBox(height: 12),
                    const DataInsightCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAttendance(BuildContext context, WidgetRef ref) async {
    final range = ref.read(statisticsPeriodProvider);

    try {
      final records = await ref.read(attendanceDaoProvider).getByDateRange(range.from, range.to);
      final students = await ref.read(studentDaoProvider).getAll();
      final nameMap = buildDisplayNameMap(students);

      final path = await ExcelExporter.exportAllAttendance(
        from: range.from,
        to: range.to,
        records: records,
        studentNames: nameMap,
      );

      if (context.mounted) {
        await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, '导出失败：$e');
      }
    }
  }
}

class _StatisticsOverviewCard extends ConsumerWidget {
  final StatisticsRange range;
  final String periodLabel;
  final String periodDescription;
  final VoidCallback onExport;

  const _StatisticsOverviewCard({
    required this.range,
    required this.periodLabel,
    required this.periodDescription,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final buttonWidth = compact ? constraints.maxWidth : 136.0;
          final contentWidth = compact ? constraints.maxWidth : constraints.maxWidth - buttonWidth - 14;
          final summaryWidth = constraints.maxWidth < 460
              ? (constraints.maxWidth - 12) / 2
              : (constraints.maxWidth - 24) / 3;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: contentWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: kSealRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.tune_outlined, color: kSealRed),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '统计周期与导出',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                periodDescription,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _RangeChip(
                                    icon: Icons.event_note_outlined,
                                    label: periodLabel,
                                    color: kPrimaryBlue,
                                  ),
                                  _RangeChip(
                                    icon: Icons.date_range_outlined,
                                    label: '${range.from} 至 ${range.to}',
                                    color: kSealRed,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: onExport,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('导出当前周期'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<StatisticsPeriod>(
                  segments: const [
                    ButtonSegment(
                      value: StatisticsPeriod.week,
                      icon: Icon(Icons.calendar_view_week_outlined, size: 18),
                      label: Text('周视图'),
                    ),
                    ButtonSegment(
                      value: StatisticsPeriod.month,
                      icon: Icon(Icons.calendar_view_month_outlined, size: 18),
                      label: Text('月视图'),
                    ),
                    ButtonSegment(
                      value: StatisticsPeriod.year,
                      icon: Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text('年视图'),
                    ),
                  ],
                  selected: {range.period},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    ref.read(statisticsPeriodProvider.notifier).state = buildStatisticsRange(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: summaryWidth,
                    child: _PeriodMetric(
                      label: '统计周期',
                      value: periodLabel,
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: summaryWidth,
                    child: _PeriodMetric(
                      label: '开始日期',
                      value: range.from,
                      color: kSealRed,
                    ),
                  ),
                  SizedBox(
                    width: summaryWidth,
                    child: _PeriodMetric(
                      label: '结束日期',
                      value: range.to,
                      color: kGreen,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RangeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PeriodMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PeriodMetric({
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
            style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
