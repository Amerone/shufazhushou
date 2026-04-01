import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/business_data_summary.dart';
import '../../../core/models/data_insight_result.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/ai_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/contribution_provider.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/insight_provider.dart';
import '../../../core/providers/metrics_provider.dart';
import '../../../core/providers/statistics_period_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/services/insight_aggregation_service.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';

class DataInsightCard extends ConsumerStatefulWidget {
  const DataInsightCard({super.key});

  @override
  ConsumerState<DataInsightCard> createState() => _DataInsightCardState();
}

class _DataInsightCardState extends ConsumerState<DataInsightCard> {
  bool _analyzing = false;
  String? _errorText;
  DataInsightResult? _result;
  DateTime? _analyzedAt;
  int _analysisRequestId = 0;
  ProviderSubscription<StatisticsRange>? _periodSubscription;

  @override
  void initState() {
    super.initState();
    _periodSubscription = ref.listenManual<StatisticsRange>(
      statisticsPeriodProvider,
      (previous, next) {
        if (previous == null) return;
        if (previous.period == next.period &&
            previous.from == next.from &&
            previous.to == next.to) {
          return;
        }
        if (!mounted) return;
        _analysisRequestId += 1;
        setState(() {
          _analyzing = false;
          _result = null;
          _errorText = null;
          _analyzedAt = null;
        });
      },
    );
  }

  @override
  void dispose() {
    _periodSubscription?.close();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final service = ref.read(dataInsightServiceProvider);
    if (service == null) {
      AppToast.showError(
        context,
        '\u8bf7\u5148\u5728\u8bbe\u7f6e\u4e2d\u5b8c\u6210 AI \u914d\u7f6e\u3002',
      );
      return;
    }

    final range = ref.read(statisticsPeriodProvider);
    final currentRequestId = ++_analysisRequestId;

    setState(() {
      _analyzing = true;
      _errorText = null;
      _result = null;
      _analyzedAt = null;
    });

    try {
      final metricsFuture = ref.read(metricsProvider.future);
      final contributionsFuture = ref.read(contributionProvider.future);
      final studentMetaFuture = ref.read(studentProvider.future);
      final statusDistributionFuture = ref
          .read(attendanceDaoProvider)
          .getStatusDistribution(range.from, range.to);
      final periodRevenueFuture = ref
          .read(paymentDaoProvider)
          .getTotalByDateRange(range.from, range.to);

      final metrics = await metricsFuture;
      final contributions = await contributionsFuture;
      final studentMeta = await studentMetaFuture;
      final statusDistribution = await statusDistributionFuture;
      final periodRevenue = await periodRevenueFuture;
      if (!mounted || currentRequestId != _analysisRequestId) return;

      final students = studentMeta
          .map((item) => item.student)
          .toList(growable: false);
      final periodInsightsFuture = _buildPeriodInsights(
        range: range,
        students: students,
        activeStudentCount: metrics.activeStudentCount,
      );
      final topContributorsFuture = _buildTopContributors(
        range: range,
        students: students,
        contributions: contributions,
      );
      final periodInsights = await periodInsightsFuture;
      final topContributors = await topContributorsFuture;
      if (!mounted || currentRequestId != _analysisRequestId) return;

      final summary = BusinessDataSummary(
        periodLabel: '${range.from} \u81f3 ${range.to}',
        activeStudentCount: metrics.activeStudentCount,
        inactiveStudentCount: math.max(
          0,
          students.length - metrics.activeStudentCount,
        ),
        periodRevenue: periodRevenue,
        attendanceStatusDistribution: <String, int>{
          for (final row in statusDistribution)
            row['status']?.toString() ?? '\u672a\u77e5':
                ((row['count'] as num?) ?? 0).toInt(),
        },
        topContributors: topContributors,
        riskStudentNames: _extractRiskStudents(periodInsights),
        insightMessages: periodInsights
            .take(6)
            .map(_formatInsightMessage)
            .toList(growable: false),
      );

      final result = await service.analyzeBusinessData(summary);
      if (!mounted || currentRequestId != _analysisRequestId) return;
      setState(() {
        _result = result;
        _analyzedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted || currentRequestId != _analysisRequestId) return;
      setState(() {
        _errorText = error.toString();
        _result = null;
        _analyzedAt = null;
      });
    } finally {
      if (mounted && currentRequestId == _analysisRequestId) {
        setState(() => _analyzing = false);
      }
    }
  }

  Future<List<Insight>> _buildPeriodInsights({
    required StatisticsRange range,
    required List<Student> students,
    required int activeStudentCount,
  }) async {
    final attendance = await ref
        .read(attendanceDaoProvider)
        .getAllGroupedByStudent();
    final payments = await ref.read(paymentDaoProvider).getTotalByAllStudents();
    final dismissedKeys = await ref
        .read(dismissedInsightDaoProvider)
        .getAllActiveKeys();
    final displayNames = buildDisplayNameMap(students);
    final service = ref.read(insightServiceProvider);

    return service.buildInsights(
      students: students,
      displayNames: displayNames,
      allAttendance: attendance,
      allPayments: payments,
      dismissedKeys: dismissedKeys,
      activeStudentCount: activeStudentCount,
      activePeriodLabel: _periodLabel(range.period),
      now: DateTime.now(),
    );
  }

  Future<List<BusinessContributorSnapshot>> _buildTopContributors({
    required StatisticsRange range,
    required List<Student> students,
    required List<Map<String, dynamic>> contributions,
  }) async {
    final displayNames = buildDisplayNameMap(students);
    final attendanceCountByStudent = <String, int>{
      for (final row in contributions)
        (row['studentId'] ?? '').toString():
            ((row['attendanceCount'] as num?) ?? 0).toInt(),
    };
    final paymentTotals = await ref
        .read(paymentDaoProvider)
        .getTotalByAllStudentsAndDateRange(range.from, range.to);

    final snapshots =
        paymentTotals.entries
            .where((entry) => entry.value > 0)
            .map(
              (entry) => BusinessContributorSnapshot(
                name: displayNames[entry.key] ?? entry.key,
                totalFee: entry.value,
                attendanceCount: attendanceCountByStudent[entry.key] ?? 0,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.totalFee.compareTo(a.totalFee));

    return snapshots.take(5).toList(growable: false);
  }

  String _periodLabel(StatisticsPeriod period) {
    switch (period) {
      case StatisticsPeriod.week:
        return '\u672c\u5468';
      case StatisticsPeriod.month:
        return '\u672c\u6708';
      case StatisticsPeriod.year:
        return '\u672c\u5e74';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = ref.watch(dataInsightServiceProvider);
    final canRun = service != null && !_analyzing;
    final result = _result;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kSealRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: kSealRed,
                  size: 20,
                ),
              ),
              SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI \u7ecf\u8425\u6d1e\u5bdf',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u57fa\u4e8e\u5f53\u524d\u7edf\u8ba1\u5468\u671f\u7684\u6d3b\u8dc3\u5ea6\u3001\u8425\u6536\u4e0e\u63d0\u9192\u751f\u6210\u7ecf\u8425\u5206\u6790\u3002',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: canRun ? _runAnalysis : null,
              icon: _analyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.insights_outlined),
              label: Text(
                _analyzing
                    ? '\u5206\u6790\u4e2d...'
                    : service == null
                    ? '\u5148\u5b8c\u6210 AI \u914d\u7f6e'
                    : '\u83b7\u53d6\u6570\u636e\u6d1e\u5bdf',
              ),
            ),
          ),
          if (service == null) ...[
            const SizedBox(height: 10),
            Text(
              '\u672a\u914d\u7f6e\u65f6\u4e0d\u4f1a\u53d1\u8d77 AI \u8bf7\u6c42\uff0c\u8bf7\u5148\u5728\u8bbe\u7f6e\u9875\u5b8c\u6210 AI \u914d\u7f6e\u3002',
              style: theme.textTheme.bodySmall?.copyWith(color: kOrange),
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(color: kRed),
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            if (_analyzedAt != null)
              Text(
                '\u751f\u6210\u65f6\u95f4\uff1a${_formatTime(_analyzedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 10),
            _InsightBlock(
              title: '\u7ecf\u8425\u6982\u51b5',
              content: result.summary,
            ),
            const SizedBox(height: 10),
            _InsightBlock(
              title: '\u8425\u6536\u6d1e\u5bdf',
              content: result.revenueInsight,
            ),
            const SizedBox(height: 10),
            _InsightBlock(
              title: '\u6d3b\u8dc3\u5ea6\u5206\u6790',
              content: result.engagementInsight,
            ),
            if (result.riskAlerts.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ListBlock(
                title: '\u98ce\u9669\u63d0\u9192',
                items: result.riskAlerts,
                color: kSealRed,
              ),
            ],
            if (result.recommendations.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ListBlock(
                title: '\u7ecf\u8425\u5efa\u8bae',
                items: result.recommendations,
                color: kGreen,
              ),
            ],
            if (!result.isStructured && result.rawText.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _InsightBlock(
                title: '\u539f\u59cb\u7ed3\u679c',
                content: result.rawText,
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<String> _extractRiskStudents(List<Insight> insights) {
    final names = <String>{};
    for (final insight in insights) {
      if (insight.type != InsightType.debt &&
          insight.type != InsightType.churn &&
          insight.type != InsightType.renewal) {
        continue;
      }
      final name = insight.studentName.trim();
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    return names.take(8).toList(growable: false);
  }

  String _formatInsightMessage(Insight insight) {
    final studentName = insight.studentName.trim();
    if (studentName.isEmpty) return insight.message;
    return '$studentName: ${insight.message}';
  }

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$month-$day $hour:$minute';
  }
}

class _InsightBlock extends StatelessWidget {
  final String title;
  final String content;

  const _InsightBlock({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = content.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: kPrimaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text.isEmpty ? '\u6682\u65e0\u5185\u5bb9\u3002' : text,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ListBlock extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;

  const _ListBlock({
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 6),
              child: Text(
                '${i + 1}. ${items[i]}',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
