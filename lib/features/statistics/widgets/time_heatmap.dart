import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/heatmap_provider.dart';
import '../../../shared/theme.dart';

class TimeHeatmap extends ConsumerStatefulWidget {
  const TimeHeatmap({super.key});

  @override
  ConsumerState<TimeHeatmap> createState() => _TimeHeatmapState();
}

class _TimeHeatmapState extends ConsumerState<TimeHeatmap> {
  String? _tooltip;

  static const _hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];
  static const _days = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncHeatmap = ref.watch(heatmapProvider);

    return asyncHeatmap.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
      data: (data) {
        final map = <String, int>{};
        var maxCount = 1;

        for (final row in data) {
          final wd = row['weekday'] as int;
          final dayIdx = wd == 0 ? 6 : wd - 1;
          final hour = row['hour'] as int;
          final count = row['count'] as int;
          map['$dayIdx-$hour'] = count;
          if (count > maxCount) maxCount = count;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tooltip ?? '点击任一色块可查看对应星期和小时的人次分布。',
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
                      const SizedBox(height: 20),
                      ..._hours.map(
                        (h) => SizedBox(
                          height: 20,
                          child: Text('$h', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
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
                            height: 20,
                            width: 28,
                            child: Center(
                              child: Text(
                                _days[dayIdx],
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                              ),
                            ),
                          ),
                          ..._hours.map((h) {
                            final count = map['$dayIdx-$h'] ?? 0;
                            final opacity = count == 0 ? 0.05 : count / maxCount;

                            return GestureDetector(
                              onTap: () => setState(
                                () => _tooltip = '周${_days[dayIdx]} $h:00  $count 人次',
                              ),
                              child: Container(
                                width: 28,
                                height: 20,
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: kPrimaryBlue.withValues(alpha: opacity),
                                  borderRadius: BorderRadius.circular(6),
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
}

class _HeatLevelChip extends StatelessWidget {
  final String label;
  final double opacity;

  const _HeatLevelChip({
    required this.label,
    required this.opacity,
  });

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
