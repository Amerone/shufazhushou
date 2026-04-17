import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'attendance_provider.dart';
import 'statistics_period_provider.dart';

class HeatmapNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() {
    final range = ref.watch(statisticsPeriodProvider);
    return ref.read(attendanceDaoProvider).getTimeHeatmap(range.from, range.to);
  }
}

final heatmapProvider =
    AsyncNotifierProvider<HeatmapNotifier, List<Map<String, dynamic>>>(
      HeatmapNotifier.new,
    );
