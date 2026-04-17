import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/payment_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/fee_summary_provider.dart';
import 'package:moyun/core/providers/revenue_provider.dart';
import 'package:moyun/core/providers/statistics_period_provider.dart';

void main() {
  test(
    'RevenueNotifier queries monthly revenue inside the active statistics range',
    () async {
      final attendanceDao = _FakeAttendanceDao();
      final paymentDao = _FakePaymentDao();
      final container = ProviderContainer(
        overrides: [
          attendanceDaoProvider.overrideWithValue(attendanceDao),
          paymentDaoProvider.overrideWithValue(paymentDao),
          statisticsNowProvider.overrideWith((ref) => DateTime(2026, 4, 3)),
        ],
      );
      addTearDown(container.dispose);

      container.read(statisticsPeriodSelectionProvider.notifier).state =
          StatisticsPeriod.year;
      final revenue = await container.read(revenueProvider.future);

      expect(attendanceDao.from, '2026-01-01');
      expect(attendanceDao.to, '2026-12-31');
      expect(paymentDao.from, '2026-01-01');
      expect(paymentDao.to, '2026-12-31');
      expect(revenue.monthlyReceivable, isNotEmpty);
      expect(revenue.monthlyReceived, isNotEmpty);
    },
  );

  test(
    'RevenueNotifier starts receivable and received queries concurrently',
    () async {
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

      final revenueFuture = container.read(revenueProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(attendanceDao.started, isTrue);
      expect(paymentDao.started, isTrue);

      attendanceDao.complete();
      paymentDao.complete();
      final revenue = await revenueFuture;

      expect(revenue.monthlyReceivable.single['totalFee'], 300);
      expect(revenue.monthlyReceived.single['totalReceived'], 280);
    },
  );
}

class _FakeAttendanceDao extends AttendanceDao {
  String? from;
  String? to;

  _FakeAttendanceDao() : super(DatabaseHelper.instance);

  @override
  Future<List<Map<String, dynamic>>> getMonthlyRevenue(
    String from,
    String to,
  ) async {
    this.from = from;
    this.to = to;
    return const [
      {'month': '2026-01', 'totalFee': 300},
    ];
  }
}

class _FakePaymentDao extends PaymentDao {
  String? from;
  String? to;

  _FakePaymentDao() : super(DatabaseHelper.instance);

  @override
  Future<List<Map<String, dynamic>>> getMonthlyReceived(
    String from,
    String to,
  ) async {
    this.from = from;
    this.to = to;
    return const [
      {'month': '2026-01', 'totalReceived': 280},
    ];
  }
}

class _BlockingAttendanceDao extends AttendanceDao {
  final _completer = Completer<List<Map<String, dynamic>>>();
  bool started = false;

  _BlockingAttendanceDao() : super(DatabaseHelper.instance);

  @override
  Future<List<Map<String, dynamic>>> getMonthlyRevenue(String from, String to) {
    started = true;
    return _completer.future;
  }

  void complete() {
    _completer.complete(const [
      {'month': '2026-01', 'totalFee': 300},
    ]);
  }
}

class _BlockingPaymentDao extends PaymentDao {
  final _completer = Completer<List<Map<String, dynamic>>>();
  bool started = false;

  _BlockingPaymentDao() : super(DatabaseHelper.instance);

  @override
  Future<List<Map<String, dynamic>>> getMonthlyReceived(
    String from,
    String to,
  ) {
    started = true;
    return _completer.future;
  }

  void complete() {
    _completer.complete(const [
      {'month': '2026-01', 'totalReceived': 280},
    ]);
  }
}
