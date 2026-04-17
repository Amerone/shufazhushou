import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/payment_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/fee_summary_provider.dart';
import 'package:moyun/core/providers/metrics_provider.dart';
import 'package:moyun/core/providers/statistics_period_provider.dart';

void main() {
  test('metricsProvider starts independent DAO queries concurrently', () async {
    final attendanceDao = _BlockingAttendanceDao();
    final paymentDao = _BlockingPaymentDao();
    final container = ProviderContainer(
      overrides: [
        attendanceDaoProvider.overrideWithValue(attendanceDao),
        paymentDaoProvider.overrideWithValue(paymentDao),
        statisticsNowProvider.overrideWith((ref) => DateTime(2026, 4, 3)),
      ],
    );
    addTearDown(container.dispose);

    container.read(statisticsPeriodSelectionProvider.notifier).state =
        StatisticsPeriod.month;
    final metricsFuture = container.read(metricsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(attendanceDao.started, isTrue);
    expect(paymentDao.started, isTrue);
    expect(attendanceDao.from, '2026-04-01');
    expect(attendanceDao.to, '2026-04-30');
    expect(paymentDao.from, '2026-04-01');
    expect(paymentDao.to, '2026-04-30');

    attendanceDao.complete();
    paymentDao.complete();

    final metrics = await metricsFuture;

    expect(metrics.totalReceivable, 300);
    expect(metrics.totalReceived, 180);
    expect(metrics.presentCount, 2);
    expect(metrics.lateCount, 1);
    expect(metrics.absentCount, 1);
    expect(metrics.activeStudentCount, 3);
  });
}

class _BlockingAttendanceDao extends AttendanceDao {
  final Completer<Map<String, dynamic>> _completer = Completer();
  bool started = false;
  String? from;
  String? to;

  _BlockingAttendanceDao() : super(DatabaseHelper.instance);

  @override
  Future<Map<String, dynamic>> getMetrics(String from, String to) {
    started = true;
    this.from = from;
    this.to = to;
    return _completer.future;
  }

  void complete() {
    _completer.complete(const {
      'totalFee': 300,
      'presentCount': 2,
      'lateCount': 1,
      'absentCount': 1,
      'activeStudentCount': 3,
    });
  }
}

class _BlockingPaymentDao extends PaymentDao {
  final Completer<double> _completer = Completer();
  bool started = false;
  String? from;
  String? to;

  _BlockingPaymentDao() : super(DatabaseHelper.instance);

  @override
  Future<double> getTotalByDateRange(String? from, String? to) {
    started = true;
    this.from = from;
    this.to = to;
    return _completer.future;
  }

  void complete() {
    _completer.complete(180);
  }
}
