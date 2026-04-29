import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/statistics_period_provider.dart';
import 'package:moyun/core/providers/status_distribution_provider.dart';
import 'package:moyun/core/providers/status_filter_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/statistics/widgets/contribution_chart.dart';
import 'package:moyun/shared/theme.dart';

void main() {
  testWidgets('status filtered list limits preview and reports total count', (
    tester,
  ) async {
    final dao = _PreviewAttendanceDao(
      List.generate(45, (index) => _attendance(index + 1)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statisticsPeriodProvider.overrideWith(
            (ref) => const StatisticsRange(
              period: StatisticsPeriod.month,
              from: '2026-04-01',
              to: '2026-04-30',
            ),
          ),
          statusFilterProvider.overrideWith((ref) => 'present'),
          attendanceDaoProvider.overrideWithValue(dao),
          statusDistributionProvider.overrideWith(
            _PresentDistributionNotifier.new,
          ),
          studentProvider.overrideWith(_EmptyStudentNotifier.new),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: StatusFilteredList()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(dao.lastLimit, filteredAttendancePreviewLimit);
    expect(find.textContaining('30 / 45'), findsOneWidget);
    expect(find.text('student-30'), findsOneWidget);
    expect(find.text('student-31'), findsNothing);
  });
}

Attendance _attendance(int index) {
  return Attendance(
    id: 'attendance-$index',
    studentId: 'student-$index',
    date: '2026-04-${index.toString().padLeft(2, '0')}',
    startTime: '18:00',
    endTime: '19:00',
    status: 'present',
    priceSnapshot: 180,
    feeAmount: 180,
    createdAt: index,
    updatedAt: index,
  );
}

class _PreviewAttendanceDao extends AttendanceDao {
  final List<Attendance> records;
  int? lastLimit;

  _PreviewAttendanceDao(this.records) : super(DatabaseHelper.instance);

  @override
  Future<List<Attendance>> getByDateRangeAndStatus(
    String from,
    String to,
    String status, {
    int? limit,
  }) async {
    lastLimit = limit;
    return records.take(limit ?? records.length).toList(growable: false);
  }
}

class _PresentDistributionNotifier extends StatusDistributionNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async => const [
    {'status': 'present', 'count': 45},
  ];
}

class _EmptyStudentNotifier extends StudentNotifier {
  @override
  Future<List<StudentWithMeta>> build() async => const [];
}
