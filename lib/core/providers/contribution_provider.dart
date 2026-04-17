import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'attendance_provider.dart';
import 'statistics_period_provider.dart';

class ContributionNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() {
    final range = ref.watch(statisticsPeriodProvider);
    return ref
        .read(attendanceDaoProvider)
        .getStudentContribution(range.from, range.to);
  }
}

final contributionProvider =
    AsyncNotifierProvider<ContributionNotifier, List<Map<String, dynamic>>>(
      ContributionNotifier.new,
    );
