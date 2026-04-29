import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/contribution_provider.dart';
import '../../../core/providers/status_distribution_provider.dart';
import '../../../core/providers/status_filter_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import 'statistics_load_error.dart';

const int _topContributionLimit = 10;

class ContributionChart extends ConsumerStatefulWidget {
  const ContributionChart({super.key});

  @override
  ConsumerState<ContributionChart> createState() => _ContributionChartState();
}

class _ContributionChartState extends ConsumerState<ContributionChart> {
  bool _byFee = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncContribution = ref.watch(contributionProvider);
    final displayNames = ref.watch(studentDisplayNameMapProvider);

    return asyncContribution.when(
      loading: () => Semantics(
        container: true,
        liveRegion: true,
        label: '\u5b66\u751f\u8d21\u732e\u52a0\u8f7d\u4e2d',
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => StatisticsLoadError(
        message: buildStatisticsErrorMessage('学生贡献', e),
        onRetry: () => ref.invalidate(contributionProvider),
      ),
      data: (list) {
        final topEntries = _rankContributions(list, byFee: _byFee);
        if (topEntries.isEmpty) {
          return const EmptyState(
            message:
                '\u5f53\u524d\u5468\u671f\u6682\u65e0\u5b66\u751f\u8d21\u732e\u6570\u636e',
            icon: Icons.groups_2_outlined,
            semanticLabel:
                '\u5f53\u524d\u5468\u671f\u6682\u65e0\u5b66\u751f\u8d21\u732e\u6570\u636e',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 380;
                final description = Text(
                  _byFee ? '金额前 10' : '节数前 10',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                );
                final selector = Semantics(
                  container: true,
                  label: '\u8d21\u732e\u6392\u540d\u7ef4\u5ea6',
                  value: _byFee ? '\u6309\u91d1\u989d' : '\u6309\u8bfe\u6b21',
                  hint:
                      '\u70b9\u6309\u53ef\u5207\u6362\u5b66\u751f\u8d21\u732e\u6392\u540d\u7ef4\u5ea6',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('金额')),
                        ButtonSegment(value: false, label: Text('节数')),
                      ],
                      selected: {_byFee},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _byFee = s.first),
                    ),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      description,
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: selector,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: 12),
                    selector,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            ...topEntries.map((entry) {
              final item = entry.item;
              final accentColor = _byFee ? kPrimaryBlue : kGreen;
              final studentId = item['studentId'] as String;
              final studentName =
                  displayNames[studentId] ?? item['studentName'] as String;
              final metricLabel = _byFee
                  ? '¥${entry.value.toStringAsFixed(0)}'
                  : '${entry.value.toInt()}节';

              return Padding(
                padding: EdgeInsets.only(
                  bottom: entry.rank == topEntries.length ? 0 : 10,
                ),
                child: Semantics(
                  button: true,
                  label:
                      '\u67e5\u770b$studentName\u6863\u6848\uff0c\u6392\u540d\u7b2c${entry.rank}\uff0c\u8d21\u732e$metricLabel',
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () => context.push('/students/$studentId'),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.56),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${entry.rank}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          studentName,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          metricLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: accentColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: kInkSecondary.withValues(
                                            alpha: 0.14,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: entry.ratio,
                                        child: _byFee
                                            ? Container(
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: accentColor.withValues(
                                                    alpha: 0.72,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                              )
                                            : _buildSegmentedBar(
                                                item,
                                                entry.value,
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (!_byFee) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: kStatusColor.entries
                    .map(
                      (e) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, color: e.value),
                          const SizedBox(width: 4),
                          Text(
                            kStatusLabel[e.key] ?? e.key.name,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSegmentedBar(Map<String, dynamic> item, double total) {
    if (total <= 0) return const SizedBox(height: 18);

    final parts = <_Segment>[];
    for (final entry in {
      'present': ((item['presentCount'] as num?) ?? 0).toDouble(),
      'late': ((item['lateCount'] as num?) ?? 0).toDouble(),
      'absent': ((item['absentCount'] as num?) ?? 0).toDouble(),
      'leave': ((item['leaveCount'] as num?) ?? 0).toDouble(),
      'trial': ((item['trialCount'] as num?) ?? 0).toDouble(),
    }.entries) {
      if (entry.value > 0) {
        parts.add(_Segment(entry.value / total, statusColor(entry.key)));
      }
    }

    return SizedBox(
      height: 18,
      child: Row(
        children: parts
            .map(
              (s) => Expanded(
                flex: math.max(1, (s.ratio * 1000).round()),
                child: Container(color: s.color),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Segment {
  final double ratio;
  final Color color;
  const _Segment(this.ratio, this.color);
}

class _ContributionEntry {
  final int rank;
  final Map<String, dynamic> item;
  final double value;
  final double ratio;

  const _ContributionEntry({
    required this.rank,
    required this.item,
    required this.value,
    required this.ratio,
  });
}

List<_ContributionEntry> _rankContributions(
  List<Map<String, dynamic>> list, {
  required bool byFee,
}) {
  final top = <({Map<String, dynamic> item, double value})>[];
  for (final item in list) {
    final value = _contributionValue(item, byFee);
    var insertAt = 0;
    while (insertAt < top.length && top[insertAt].value >= value) {
      insertAt++;
    }
    if (insertAt >= _topContributionLimit) continue;
    top.insert(insertAt, (item: item, value: value));
    if (top.length > _topContributionLimit) {
      top.removeLast();
    }
  }

  if (top.isEmpty) {
    return const <_ContributionEntry>[];
  }

  final maxValue = top.first.value;
  final entries = <_ContributionEntry>[];
  for (var i = 0; i < top.length; i++) {
    final item = top[i].item;
    final value = top[i].value;
    entries.add(
      _ContributionEntry(
        rank: i + 1,
        item: item,
        value: value,
        ratio: maxValue > 0 ? value / maxValue : 0,
      ),
    );
  }
  return entries;
}

double _contributionValue(Map<String, dynamic> item, bool byFee) {
  if (byFee) {
    return ((item['totalFee'] as num?) ?? 0).toDouble();
  }
  return ((item['attendanceCount'] as num?) ?? 0).toDouble();
}

class StatusPieChart extends ConsumerWidget {
  const StatusPieChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDistribution = ref.watch(statusDistributionProvider);
    final selected = ref.watch(statusFilterProvider);

    return asyncDistribution.when(
      loading: () => Semantics(
        container: true,
        liveRegion: true,
        label: '\u72b6\u6001\u5206\u5e03\u52a0\u8f7d\u4e2d',
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => StatisticsLoadError(
        message: buildStatisticsErrorMessage('状态分布', e),
        onRetry: () => ref.invalidate(statusDistributionProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            message:
                '\u5f53\u524d\u5468\u671f\u6682\u65e0\u51fa\u52e4\u72b6\u6001\u5206\u5e03',
            icon: Icons.pie_chart_outline_rounded,
            semanticLabel:
                '\u5f53\u524d\u5468\u671f\u6682\u65e0\u51fa\u52e4\u72b6\u6001\u5206\u5e03',
          );
        }

        return Semantics(
          container: true,
          label:
              '\u72b6\u6001\u5206\u5e03\u997c\u56fe\uff0c\u70b9\u6309\u6247\u533a\u53ef\u7b5b\u9009\u5bf9\u5e94\u51fa\u52e4\u8bb0\u5f55',
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions) return;
                    final idx = response?.touchedSection?.touchedSectionIndex;
                    if (idx == null || idx < 0 || idx >= list.length) return;
                    final status = list[idx]['status'] as String;
                    ref.read(statusFilterProvider.notifier).state =
                        selected == status ? null : status;
                  },
                ),
                sections: list.asMap().entries.map((e) {
                  final status = e.value['status'] as String;
                  final count = (e.value['count'] as num?) ?? 0;
                  final isSelected = selected == status;

                  return PieChartSectionData(
                    value: count.toDouble(),
                    color: statusColor(status),
                    title: '${statusLabel(status)}\n$count',
                    radius: isSelected ? 70 : 60,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class StatusFilteredList extends ConsumerWidget {
  const StatusFilteredList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(statusFilterProvider);
    if (selected == null) return const SizedBox();

    final nameMap = ref.watch(studentDisplayNameMapProvider);
    final totalCount = _statusRecordTotal(
      ref.watch(statusDistributionProvider).valueOrNull,
      selected,
    );

    final asyncRecords = ref.watch(filteredAttendanceProvider);

    return asyncRecords.when(
      loading: () => Semantics(
        container: true,
        liveRegion: true,
        label: '\u72b6\u6001\u8bb0\u5f55\u52a0\u8f7d\u4e2d',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => StatisticsLoadError(
        message: buildStatisticsErrorMessage('状态记录', e),
        onRetry: () => ref.invalidate(filteredAttendanceProvider),
      ),
      data: (records) {
        if (records.isEmpty) {
          return const EmptyState(message: '\u6682\u65e0\u8bb0\u5f55');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusFilteredListSummary(
              status: selected,
              shownCount: records.length,
              totalCount: totalCount,
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              itemBuilder: (_, i) {
                final r = records[i];
                final color = statusColor(selected);
                return Container(
                  margin: EdgeInsets.only(
                    bottom: i == records.length - 1 ? 0 : 8,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameMap[r.studentId] ?? r.studentId,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r.date}  ${r.startTime}-${r.endTime}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _StatusFilteredListSummary extends StatelessWidget {
  final String status;
  final int shownCount;
  final int? totalCount;

  const _StatusFilteredListSummary({
    required this.status,
    required this.shownCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final effectiveTotal = totalCount ?? shownCount;
    final countLabel = effectiveTotal > shownCount
        ? '最近 $shownCount / $effectiveTotal 条'
        : '$shownCount 条';

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${statusLabel(status)}记录，$countLabel',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${statusLabel(status)} · $countLabel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int? _statusRecordTotal(
  List<Map<String, dynamic>>? distribution,
  String status,
) {
  if (distribution == null) return null;
  for (final item in distribution) {
    if (item['status'] == status) {
      return ((item['count'] as num?) ?? 0).toInt();
    }
  }
  return null;
}
