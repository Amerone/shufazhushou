import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/dao/attendance_dao.dart';
import '../../../core/database/dao/student_dao.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/contribution_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/heatmap_provider.dart';
import '../../../core/providers/insight_provider.dart';
import '../../../core/providers/metrics_provider.dart';
import '../../../core/providers/revenue_provider.dart';
import '../../../core/providers/statistics_period_provider.dart';
import '../../../core/providers/status_distribution_provider.dart';
import '../../../core/utils/excel_exporter.dart';
import '../../../shared/utils/toast.dart';
import '../widgets/contribution_chart.dart';
import '../widgets/insight_list.dart';
import '../widgets/metrics_grid.dart';
import '../widgets/revenue_chart.dart';
import '../widgets/time_heatmap.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导出出勤汇总',
            onPressed: () => _exportAttendance(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(metricsProvider);
          ref.invalidate(revenueProvider);
          ref.invalidate(contributionProvider);
          ref.invalidate(statusDistributionProvider);
          ref.invalidate(heatmapProvider);
          ref.invalidate(insightProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const RepaintBoundary(child: MetricsGrid()),
            const SizedBox(height: 24),
            Text('收入趋势', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const RepaintBoundary(child: RevenueChart()),
            const SizedBox(height: 24),
            const RepaintBoundary(child: ContributionChart()),
            const SizedBox(height: 24),
            Text('状态分布', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const RepaintBoundary(child: StatusPieChart()),
            const StatusFilteredList(),
            const SizedBox(height: 24),
            const RepaintBoundary(child: TimeHeatmap()),
            const SizedBox(height: 24),
            Text('智能洞察', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const InsightList(),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAttendance(BuildContext context, WidgetRef ref) async {
    final range = ref.read(statisticsPeriodProvider);
    final db = ref.read(databaseProvider);

    try {
      final records = await AttendanceDao(db).getByDateRange(range.from, range.to);
      final students = await StudentDao(db).getAll();
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
        AppToast.showError(context, '导出失败: $e');
      }
    }
  }
}
