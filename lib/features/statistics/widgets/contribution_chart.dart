import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/contribution_provider.dart';
import '../../../core/providers/status_distribution_provider.dart';
import '../../../core/providers/status_filter_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/empty_state.dart';

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
    final students = ref.watch(studentProvider).valueOrNull ?? [];
    final displayNames = buildDisplayNameMap(students.map((m) => m.student).toList());

    return asyncContribution.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
      data: (list) {
        final sorted = [...list]
          ..sort((a, b) => _byFee
              ? ((b['totalFee'] as num?) ?? 0).compareTo((a['totalFee'] as num?) ?? 0)
              : ((b['attendanceCount'] as num?) ?? 0).compareTo((a['attendanceCount'] as num?) ?? 0));

        final top = sorted.take(10).toList();
        if (top.isEmpty) return const EmptyState(message: '暂无数据');

        final maxVal = (_byFee
                ? (top.first['totalFee'] as num?) ?? 0
                : (top.first['attendanceCount'] as num?) ?? 0)
            .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _byFee ? '按金额查看前 10 名学员贡献' : '按课次查看前 10 名学员贡献',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('金额')),
                    ButtonSegment(value: false, label: Text('节数')),
                  ],
                  selected: {_byFee},
                  onSelectionChanged: (s) => setState(() => _byFee = s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...top.map((item) {
              final value = _byFee
                  ? ((item['totalFee'] as num?) ?? 0).toDouble()
                  : ((item['attendanceCount'] as num?) ?? 0).toDouble();
              final ratio = maxVal > 0 ? value / maxVal : 0.0;
              final rank = top.indexOf(item) + 1;
              final accentColor = _byFee ? kPrimaryBlue : kGreen;

              return GestureDetector(
                onTap: () => context.push('/students/${item['studentId']}'),
                child: Container(
                  margin: EdgeInsets.only(bottom: item == top.last ? 0 : 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accentColor.withValues(alpha: 0.1)),
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
                          '$rank',
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
                                    displayNames[item['studentId']] ?? item['studentName'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _byFee ? '¥${value.toStringAsFixed(0)}' : '${value.toInt()}节',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w700,
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
                                    color: kInkSecondary.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: ratio,
                                  child: _byFee
                                      ? Container(
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(alpha: 0.72),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        )
                                      : _buildSegmentedBar(item, value),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
                          Text(kStatusLabel[e.key] ?? e.key.name, style: theme.textTheme.bodySmall),
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
                flex: (s.ratio * 1000).round(),
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

class StatusPieChart extends ConsumerWidget {
  const StatusPieChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDistribution = ref.watch(statusDistributionProvider);
    final selected = ref.watch(statusFilterProvider);

    return asyncDistribution.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
      data: (list) {
        if (list.isEmpty) return const EmptyState(message: '暂无数据');

        return SizedBox(
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
                  ref.read(statusFilterProvider.notifier).state = selected == status ? null : status;
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
                  titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
                );
              }).toList(),
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

    final students = ref.watch(studentProvider).valueOrNull ?? [];
    final nameMap = buildDisplayNameMap(students.map((m) => m.student).toList());

    final asyncRecords = ref.watch(filteredAttendanceProvider);

    return asyncRecords.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
      data: (records) {
        if (records.isEmpty) return const EmptyState(message: '暂无记录');

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          itemBuilder: (_, i) {
            final r = records[i];
            final color = statusColor(selected);
            return Container(
              margin: EdgeInsets.only(bottom: i == records.length - 1 ? 0 : 8),
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
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
        );
      },
    );
  }
}
