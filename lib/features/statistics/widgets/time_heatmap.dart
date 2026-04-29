import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/heatmap_provider.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import 'statistics_load_error.dart';

class TimeHeatmap extends ConsumerStatefulWidget {
  const TimeHeatmap({super.key});

  @override
  ConsumerState<TimeHeatmap> createState() => _TimeHeatmapState();
}

class _TimeHeatmapState extends ConsumerState<TimeHeatmap> {
  String? _tooltip;
  List<Map<String, dynamic>>? _cachedHeatmapData;
  _HeatmapSnapshot? _cachedHeatmapSnapshot;

  static const _hours = [
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
  ];
  static const _days = [
    '\u4e00',
    '\u4e8c',
    '\u4e09',
    '\u56db',
    '\u4e94',
    '\u516d',
    '\u65e5',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncHeatmap = ref.watch(heatmapProvider);

    return asyncHeatmap.when(
      loading: () => Semantics(
        container: true,
        liveRegion: true,
        label: '\u4e0a\u8bfe\u70ed\u529b\u52a0\u8f7d\u4e2d',
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => StatisticsLoadError(
        message: buildStatisticsErrorMessage('上课热力', e),
        onRetry: () => ref.invalidate(heatmapProvider),
      ),
      data: (data) {
        if (data.isEmpty) {
          return const EmptyState(
            message: '\u6682\u65e0\u65f6\u6bb5\u6570\u636e',
            icon: Icons.grid_view_outlined,
            semanticLabel: '\u6682\u65e0\u65f6\u6bb5\u6570\u636e',
          );
        }

        final snapshot = _snapshotFor(data);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tooltip ?? '\u70b9\u8272\u5757\u67e5\u770b\u4eba\u6b21\u3002',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _HeatLevelChip(label: '低频', opacity: 0.08),
                _HeatLevelChip(label: '中频', opacity: 0.4),
                _HeatLevelChip(label: '高频', opacity: 0.85),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 24),
                      ..._hours.map(
                        (h) => SizedBox(
                          height: 44,
                          child: Text(
                            '$h',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Row(
                    children: List.generate(7, (dayIdx) {
                      return Column(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 48,
                            child: Center(
                              child: Text(
                                _days[dayIdx],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          ..._hours.map((h) {
                            final count = snapshot.count(dayIdx, h);
                            final opacity = count == 0
                                ? 0.05
                                : count / snapshot.maxCount;
                            final cellLabel =
                                '\u5468${_days[dayIdx]} $h:00\uff0c$count \u4eba\u6b21';
                            void selectCell() {
                              setState(() => _tooltip = cellLabel);
                            }

                            return Padding(
                              padding: const EdgeInsets.all(2),
                              child: Tooltip(
                                message: cellLabel,
                                child: Semantics(
                                  button: true,
                                  label: cellLabel,
                                  onTap: selectCell,
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      mouseCursor: SystemMouseCursors.click,
                                      onTap: selectCell,
                                      child: SizedBox(
                                        width: 44,
                                        height: 40,
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            color: kPrimaryBlue.withValues(
                                              alpha: opacity,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  _HeatmapSnapshot _snapshotFor(List<Map<String, dynamic>> data) {
    final cached = _cachedHeatmapSnapshot;
    if (identical(_cachedHeatmapData, data) && cached != null) {
      return cached;
    }

    final counts = <String, int>{};
    var maxCount = 1;
    for (final row in data) {
      final wd = row['weekday'] as int;
      final dayIdx = wd == 0 ? 6 : wd - 1;
      final hour = row['hour'] as int;
      final count = row['count'] as int;
      counts['$dayIdx-$hour'] = count;
      if (count > maxCount) maxCount = count;
    }

    final snapshot = _HeatmapSnapshot(counts, maxCount);
    _cachedHeatmapData = data;
    _cachedHeatmapSnapshot = snapshot;
    return snapshot;
  }
}

class _HeatmapSnapshot {
  final Map<String, int> counts;
  final int maxCount;

  const _HeatmapSnapshot(this.counts, this.maxCount);

  int count(int dayIdx, int hour) => counts['$dayIdx-$hour'] ?? 0;
}

class _HeatLevelChip extends StatelessWidget {
  final String label;
  final double opacity;

  const _HeatLevelChip({required this.label, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
