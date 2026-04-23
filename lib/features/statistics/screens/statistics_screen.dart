import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/student.dart' show buildDisplayNameMap;
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
  bool _exporting = false;
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
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.offset > 280;
    final activeAnchor = _resolveVisibleAnchor();
    if (shouldShow == _showScrollToTop &&
        (activeAnchor == null || activeAnchor == _lastFocusedAnchor)) {
      return;
    }
    setState(() {
      _showScrollToTop = shouldShow;
      if (activeAnchor != null) {
        _lastFocusedAnchor = activeAnchor;
      }
    });
  }

  _StatisticsAnchor? _resolveVisibleAnchor() {
    final targetY = MediaQuery.paddingOf(context).top + 92;
    _StatisticsAnchor? nearestAbove;
    var nearestAboveY = double.negativeInfinity;
    _StatisticsAnchor? nearestBelow;
    var nearestBelowDistance = double.infinity;

    for (final entry in _sectionKeys.entries) {
      final sectionContext = entry.value.currentContext;
      if (sectionContext == null) continue;
      final renderObject = sectionContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;

      final y = renderObject.localToGlobal(Offset.zero).dy;
      if (y <= targetY && y > nearestAboveY) {
        nearestAbove = entry.key;
        nearestAboveY = y;
      } else if (nearestAbove == null) {
        final distance = (y - targetY).abs();
        if (distance < nearestBelowDistance) {
          nearestBelow = entry.key;
          nearestBelowDistance = distance;
        }
      }
    }

    return nearestAbove ?? nearestBelow;
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

  Future<void> _scrollToTop({bool withFeedback = true}) async {
    if (withFeedback) {
      await InteractionFeedback.selection(context);
    }
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _exportAttendance() async {
    if (_exporting) return;
    final range = ref.read(statisticsPeriodProvider);

    setState(() => _exporting = true);
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
      final shareResult = await SharePlus.instance.share(
        ShareParams(files: [XFile(path)]),
      );
      if (shareResult.status == ShareResultStatus.dismissed) return;
      _markUpdated();
      if (!mounted) return;
      AppToast.showSuccess(context, '统计明细已生成，请在系统分享面板中保存。');
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, '导出失败：$error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(statisticsPeriodProvider);
    final periodLabel = _periodLabel(range.period);
    final updatedLabel = _formatUpdatedAt(_lastUpdatedAt);
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final horizontalPadding = MediaQuery.sizeOf(context).width < 390
        ? 16.0
        : 24.0;

    final scrollToTopAction = ExcludeSemantics(
      excluding: !_showScrollToTop,
      child: IgnorePointer(
        ignoring: !_showScrollToTop,
        child: Padding(
          padding: EdgeInsets.only(bottom: viewPaddingBottom + 80),
          child: Semantics(
            button: true,
            label: '\u8fd4\u56de\u7edf\u8ba1\u9875\u9876\u90e8',
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
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            const PageHeader(title: '经营统计'),
            Expanded(
              child: RefreshIndicator(
                color: kSealRed,
                onRefresh: () async {
                  invalidateStatistics(ref);
                  _markUpdated();
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        4,
                        horizontalPadding,
                        120,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _StatisticsOverviewCard(
                            range: range,
                            periodLabel: periodLabel,
                            updatedLabel: updatedLabel,
                            exporting: _exporting,
                            onExport: _exportAttendance,
                            onPeriodChanged: (period) {
                              ref
                                      .read(
                                        statisticsPeriodSelectionProvider
                                            .notifier,
                                      )
                                      .state =
                                  period;
                              _markUpdated();
                              setState(() => _lastFocusedAnchor = null);
                              unawaited(_scrollToTop(withFeedback: false));
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
                            child: GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: const RepaintBoundary(
                                child: MetricsGrid(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _StatisticsSectionBlock(
                            anchorKey: _sectionKeys[_StatisticsAnchor.revenue],
                            title: '收入走势',
                            child: GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: const RepaintBoundary(
                                child: RevenueChart(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _StatisticsSectionBlock(
                            anchorKey:
                                _sectionKeys[_StatisticsAnchor.contribution],
                            title: '学生贡献',
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
                            child: GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                            child: GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: const RepaintBoundary(
                                child: TimeHeatmap(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _StatisticsSectionBlock(
                            anchorKey: _sectionKeys[_StatisticsAnchor.insights],
                            title: '经营提醒',
                            child: GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: const InsightList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _StatisticsSectionBlock(
                            anchorKey: _sectionKeys[_StatisticsAnchor.ai],
                            title: 'AI 经营洞察',
                            child: const RepaintBoundary(
                              child: DataInsightCard(),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: reduceMotion
          ? Opacity(opacity: _showScrollToTop ? 1 : 0, child: scrollToTopAction)
          : AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: _showScrollToTop ? Offset.zero : const Offset(0, 1.6),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showScrollToTop ? 1 : 0,
                child: scrollToTopAction,
              ),
            ),
    );
  }
}

class _StatisticsOverviewCard extends StatelessWidget {
  final StatisticsRange range;
  final String periodLabel;
  final String updatedLabel;
  final bool exporting;
  final VoidCallback onExport;
  final ValueChanged<StatisticsPeriod> onPeriodChanged;

  const _StatisticsOverviewCard({
    required this.range,
    required this.periodLabel,
    required this.updatedLabel,
    required this.exporting,
    required this.onExport,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: kPrimaryBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$periodLabel经营总览',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${range.from} 至 ${range.to} · 更新 $updatedLabel',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            container: true,
            label: '\u7edf\u8ba1\u5468\u671f',
            value: _periodSemanticsValue(range.period),
            hint:
                '\u5de6\u53f3\u6ed1\u52a8\u67e5\u770b\u5468\u671f\u9009\u9879\uff0c\u70b9\u6309\u53ef\u5207\u6362\u7edf\u8ba1\u8303\u56f4',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: SegmentedButton<StatisticsPeriod>(
                  segments: const [
                    ButtonSegment(
                      value: StatisticsPeriod.week,
                      icon: Icon(Icons.view_week_outlined, size: 18),
                      label: Text('本周'),
                    ),
                    ButtonSegment(
                      value: StatisticsPeriod.month,
                      icon: Icon(Icons.calendar_view_month_outlined, size: 18),
                      label: Text('本月'),
                    ),
                    ButtonSegment(
                      value: StatisticsPeriod.year,
                      icon: Icon(Icons.event_available_outlined, size: 18),
                      label: Text('本年'),
                    ),
                  ],
                  selected: {range.period},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    final period = selection.first;
                    if (period == range.period) return;
                    onPeriodChanged(period);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            button: true,
            enabled: !exporting,
            liveRegion: true,
            label: exporting
                ? '\u6b63\u5728\u51c6\u5907\u5bfc\u51fa\u5f53\u524d\u5468\u671f\u660e\u7ec6'
                : '\u5bfc\u51fa\u5f53\u524d\u5468\u671f\u660e\u7ec6',
            value: _periodSemanticsValue(range.period),
            onTap: exporting ? null : onExport,
            child: ExcludeSemantics(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: exporting ? null : onExport,
                  icon: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_outlined),
                  label: Text(exporting ? '正在准备导出...' : '导出当前周期明细'),
                ),
              ),
            ),
          ),
        ],
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
      color: kGreen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '\u7edf\u8ba1\u9875\u5feb\u901f\u8df3\u8f6c',
      hint:
          '\u5de6\u53f3\u6ed1\u52a8\u67e5\u770b\u5206\u533a\uff0c\u70b9\u6309\u53ef\u8df3\u8f6c\u5230\u5bf9\u5e94\u7edf\u8ba1\u6a21\u5757',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in _items) ...[
              _StatisticsQuickNavChip(
                item: item,
                selected: activeAnchor == item.anchor,
                onTap: () => onTap(item.anchor),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
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
    final foreground = selected ? Colors.white : item.color;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: selected,
      label: '\u8df3\u8f6c\u5230${item.label}',
      hint: selected
          ? '\u5f53\u524d\u6240\u5728\u5206\u533a\uff0c\u70b9\u6309\u53ef\u91cd\u65b0\u5b9a\u4f4d\u5230${item.label}'
          : '\u70b9\u6309\u8df3\u8f6c\u5230${item.label}\u5206\u533a',
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Material(
          color: selected ? item.color : Colors.white.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatisticsSectionBlock extends StatelessWidget {
  final Key? anchorKey;
  final String title;
  final Widget child;

  const _StatisticsSectionBlock({
    required this.anchorKey,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchorKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

String _periodLabel(StatisticsPeriod period) {
  switch (period) {
    case StatisticsPeriod.week:
      return '本周';
    case StatisticsPeriod.month:
      return '本月';
    case StatisticsPeriod.year:
      return '本年';
  }
}

String _periodSemanticsValue(StatisticsPeriod period) {
  switch (period) {
    case StatisticsPeriod.week:
      return '\u672c\u5468';
    case StatisticsPeriod.month:
      return '\u672c\u6708';
    case StatisticsPeriod.year:
      return '\u672c\u5e74';
  }
}

String _formatUpdatedAt(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$month月$day日 $hour:$minute';
}
