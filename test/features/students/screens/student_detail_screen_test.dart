import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/payment_dao.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/payment.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/fee_summary_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/students/screens/student_detail_screen.dart';
import 'package:moyun/shared/theme.dart';

void main() {
  testWidgets('shows retryable alerts when ledger and payments refresh fail', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final paymentDao = _FailingPaymentDao();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentProvider.overrideWith(_FakeStudentNotifier.new),
          attendanceDaoProvider.overrideWithValue(_FakeAttendanceDao()),
          paymentDaoProvider.overrideWithValue(paymentDao),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const StudentDetailScreen(studentId: 'student-1'),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.widgetWithText(OutlinedButton, '费用'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '缴费'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '出勤'), findsOneWidget);
    expect(find.text('学员账本加载失败'), findsOneWidget);
    expect(find.text('重试账本'), findsOneWidget);
    expect(find.textContaining('可能'), findsAtLeastNWidgets(1));

    final ledgerCalls = paymentDao.allTimeSummaryCalls;
    await tester.tap(find.widgetWithText(TextButton, '重试账本'));
    await _settleUi(tester);
    expect(paymentDao.allTimeSummaryCalls, greaterThan(ledgerCalls));

    await tester.scrollUntilVisible(
      find.text('缴费记录刷新失败'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await _settleUi(tester);

    expect(find.text('缴费记录刷新失败'), findsOneWidget);
    expect(find.text('重试缴费'), findsOneWidget);
    expect(find.textContaining('可能'), findsWidgets);

    final paymentCalls = paymentDao.paymentListCalls;
    await tester.tap(find.widgetWithText(TextButton, '重试缴费'));
    await _settleUi(tester);
    expect(paymentDao.paymentListCalls, greaterThan(paymentCalls));
  });
}

class _FakeStudentNotifier extends StudentNotifier {
  @override
  Future<List<StudentWithMeta>> build() async => const [
    StudentWithMeta(
      Student(
        id: 'student-1',
        name: 'Alice',
        parentName: 'Parent A',
        parentPhone: '13900000001',
        pricePerClass: 100,
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
      ),
      null,
    ),
  ];
}

class _FakeAttendanceDao extends AttendanceDao {
  _FakeAttendanceDao() : super(DatabaseHelper.instance);

  @override
  Future<List<Attendance>> getByStudentPaged(
    String studentId,
    int limit,
    int offset,
  ) async => const [];

  @override
  Future<double> getTotalFeeByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async => 300;
}

class _FailingPaymentDao extends PaymentDao {
  int allTimeSummaryCalls = 0;
  int paymentListCalls = 0;

  _FailingPaymentDao() : super(DatabaseHelper.instance);

  @override
  Future<List<Payment>> getByStudent(String studentId) async {
    paymentListCalls++;
    throw StateError('payments offline');
  }

  @override
  Future<double> getTotalByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async {
    if (from == null && to == null) {
      allTimeSummaryCalls++;
      throw StateError('ledger offline');
    }
    return 100;
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}
