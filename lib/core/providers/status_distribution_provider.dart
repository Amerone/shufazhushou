import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'attendance_provider.dart';
import 'statistics_period_provider.dart';

class StatusDistributionNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() {
    final range = ref.watch(statisticsPeriodProvider);
    return ref
        .read(attendanceDaoProvider)
        .getStatusDistribution(range.from, range.to);
  }
}

final statusDistributionProvider =
    AsyncNotifierProvider<
      StatusDistributionNotifier,
      List<Map<String, dynamic>>
    >(StatusDistributionNotifier.new);
