import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/student.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/statistics_period_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/excel_exporter.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
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

enum _StatisticsAnchor {
  metrics,
  revenue,
  contribution,
  status,
  heatmap,
  insights,
  ai,
}

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<_StatisticsAnchor, GlobalKey> _sectionKeys = {
    for (final anchor in _StatisticsAnchor.values) anchor: GlobalKey(),
  };
  DateTime _lastUpdatedAt = DateTime.now();
  bool _showScrollToTop = false;
  _StatisticsAnchor? _lastFocusedAnchor;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset > 280;
    if (shouldShow == _showScrollToTop) return;
    setState(() => _showScrollToTop = shouldShow);
  }

  void _markUpdated() {
    if (!mounted) return;
    setState(() => _lastUpdatedAt = DateTime.now());
  }

  Future<void> _scrollToSection(_StatisticsAnchor anchor) async {
    final targetContext = _sectionKeys[anchor]?.currentContext;
    if (targetContext == null) return;

    setState(() => _lastFocusedAnchor = anchor);
    unawaited(InteractionFeedback.selection(context));
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.06,
    );
  }

  Future<void> _scrollToTop() async {
    await InteractionFeedback.selection(context);
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _exportAttendance() async {
    final range = ref.read(statisticsPeriodProvider);

    try {
      await InteractionFeedback.selection(context);
      final records = await ref
          .read(attendanceDaoProvider)
          .getByDateRange(range.from, range.to);
      final students = await ref.read(studentDaoProvider).getAll();
      final nameMap = buildDisplayNameMap(students);

      final path = await ExcelExporter.exportAllAttendance(
        from: range.from,
        to: range.to,
        records: records,
        studentNames: nameMap,
      );

      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
      _markUpdated();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, '导出失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final updatedLabel = DateFormat(
      'M月d日 HH:mm',
      'zh_CN',
    ).format(_lastUpdatedAt);
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            const PageHeader(title: '经营统计', subtitle: '查看课时收入、出勤结构和当前周期提醒。'),
            Expanded(
              child: RefreshIndicator(
                color: kSealRed,
                onRefresh: () async {
                  invalidateStatistics(ref);
                  _markUpdated();
                },
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                  children: [
                    _StatisticsOverviewCard(
                      range: range,
                      periodLabel: periodLabel,
                      periodDescription: periodDescription,
                      updatedLabel: updatedLabel,
                      onExport: _exportAttendance,
                      onPeriodChanged: () {
                        _markUpdated();
                        setState(() => _lastFocusedAnchor = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    _StatisticsQuickNavigator(
                      activeAnchor: _lastFocusedAnchor,
                      onTap: _scrollToSection,
                    ),
                    const SizedBox(height: 20),
                    _StatisticsSectionBlock(
                      anchorKey: _sectionKeys[_StatisticsAnchor.metrics],
                      title: '核心指标',
                      subtitle: '收入、出勤和活跃人数会跟随顶部周期切换自动刷新。',
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: const RepaintBoundary(child: MetricsGrid()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StatisticsSectionBlock(
                      anchorKey: _sectionKeys[_StatisticsAnchor.revenue],
                      title: '收入走势',
                      subtitle: '观察当前周期内的进账波动，及时识别高峰与空档。',
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: const RepaintBoundary(child: RevenueChart()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StatisticsSectionBlock(
                      anchorKey: _sectionKeys[_StatisticsAnchor.contribution],
                      title: '学生贡献',
                      subtitle: '对比学员在收入和到课上的贡献度，便于安排回访与续费。',
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: const RepaintBoundary(
                          child: ContributionChart(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StatisticsSectionBlock(
                      anchorKey: _sectionKeys[_StatisticsAnchor.status],
                      title: '状态分布',
                      subtitle: '查看出勤状态占比，并快速定位异常记录。',
                      child: GlassCard(
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
                    ),
                    const SizedBox(height: 24),
                    _StatisticsSectionBlock(
                      anchorKey: _sectionKeys[_StatisticsAnchor.heatmap],
                      title: '上课热力',
                      subtitle: '识别常见上课时段，为排课和招生沟通提供参考。',
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: const RepaintBoundary(child: TimeHeatmap()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StatisticsSectionBlock(
                      anchorKey: _sectionKeys[_StatisticsAnchor.insights],
                      title: '经营提醒',
                      subtitle: '聚焦当前周期内需要跟进的续费、流失与排课信号。',
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: const InsightList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StatisticsSectionBlock(
                      anchorKey: _sectionKeys[_StatisticsAnchor.ai],
                      title: 'AI 经营洞察',
                      subtitle: '基于当前周期核心数据生成经营分析和可执行建议。',
                      child: const DataInsightCard(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _showScrollToTop ? Offset.zero : const Offset(0, 1.6),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _showScrollToTop ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_showScrollToTop,
            child: Padding(
              padding: EdgeInsets.only(bottom: viewPaddingBottom + 80),
              child: FloatingActionButton.small(
                heroTag: 'statistics-scroll-top',
                onPressed: _scrollToTop,
                tooltip: '回到顶部',
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                foregroundColor: kPrimaryBlue,
                elevation: 0,
                child: const Icon(Icons.vertical_align_top_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatisticsQuickNavigator extends StatelessWidget {
  final _StatisticsAnchor? activeAnchor;
  final ValueChanged<_StatisticsAnchor> onTap;

  const _StatisticsQuickNavigator({
    required this.activeAnchor,
    required this.onTap,
  });

  static const _items = [
    _StatisticsQuickNavItem(
      anchor: _StatisticsAnchor.metrics,
      icon: Icons.dashboard_outlined,
      label: '指标',
      color: kPrimaryBlue,
    ),
    _StatisticsQuickNavItem(
      anchor: _StatisticsAnchor.revenue,
      icon: Icons.show_chart_outlined,
      label: '收入',
      color: kGreen,
    ),
    _StatisticsQuickNavItem(
      anchor: _StatisticsAnchor.contribution,
      icon: Icons.groups_2_outlined,
      label: '贡献',
      color: kSealRed,
    ),
    _StatisticsQuickNavItem(
      anchor: _StatisticsAnchor.status,
      icon: Icons.pie_chart_outline_rounded,
      label: '状态',
      color: kOrange,
    ),
    _StatisticsQuickNavItem(
      anchor: _StatisticsAnchor.heatmap,
      icon: Icons.grid_view_outlined,
      label: '热力',
      color: kPrimaryBlue,
    ),
    _StatisticsQuickNavItem(
      anchor: _StatisticsAnchor.insights,
      icon: Icons.notifications_active_outlined,
      label: '提醒',
      color: kSealRed,
    ),
    _StatisticsQuickNavItem(
      anchor: _StatisticsAnchor.ai,
      icon: Icons.auto_awesome_outlined,
      label: 'AI',
      color: kOrange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '快速定位',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '长页面目录',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kInkSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '轻触标签即可直接跳到对应分析区块，避免在长列表里反复滚动查找。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720
                  ? 4
                  : constraints.maxWidth >= 460
                  ? 3
                  : 2;
              final itemWidth =
                  (constraints.maxWidth - 10 * (columns - 1)) / columns;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in _items)
                    SizedBox(
                      width: itemWidth,
                      child: _StatisticsQuickNavChip(
                        item: item,
                        selected: activeAnchor == item.anchor,
                        onTap: () => onTap(item.anchor),
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

class _StatisticsQuickNavItem {
  final _StatisticsAnchor anchor;
  final IconData icon;
  final String label;
  final Color color;

  const _StatisticsQuickNavItem({
    required this.anchor,
    required this.icon,
    required this.label,
    required this.color,
  });
}

class _StatisticsQuickNavChip extends StatelessWidget {
  final _StatisticsQuickNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _StatisticsQuickNavChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? item.color.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.color.withValues(alpha: selected ? 0.22 : 0.1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 18, color: item.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: item.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 16, color: item.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsSectionBlock extends StatelessWidget {
  final Key? anchorKey;
  final String title;
  final String subtitle;
  final Widget child;

  const _StatisticsSectionBlock({
    this.anchorKey,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchorKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title, subtitle: subtitle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatisticsOverviewCard extends ConsumerWidget {
  final StatisticsRange range;
  final String periodLabel;
  final String periodDescription;
  final String updatedLabel;
  final VoidCallback onExport;
  final VoidCallback onPeriodChanged;

  const _StatisticsOverviewCard({
    required this.range,
    required this.periodLabel,
    required this.periodDescription,
    required this.updatedLabel,
    required this.onExport,
    required this.onPeriodChanged,
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
          final contentWidth = compact
              ? constraints.maxWidth
              : constraints.maxWidth - buttonWidth - 14;
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
                          child: const Icon(
                            Icons.tune_outlined,
                            color: kSealRed,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '统计周期与导出',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                periodDescription,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '数据更新于 $updatedLabel',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: kInkSecondary,
                                ),
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
                    unawaited(InteractionFeedback.selection(context));
                    ref.read(statisticsPeriodProvider.notifier).state =
                        buildStatisticsRange(selection.first);
                    onPeriodChanged();
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

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: theme.textTheme.bodySmall),
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
