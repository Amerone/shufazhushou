import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/payment_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/fee_summary_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/students/widgets/payment_bottom_sheet.dart';
import 'package:moyun/features/students/widgets/student_action_launcher.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  testWidgets(
    'quick amount chips fill payment field from explicit class price',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(
              body: PaymentBottomSheet(
                studentId: 'student-1',
                studentName: 'Alice',
                pricePerClass: 180,
              ),
            ),
          ),
        ),
      );
      await _settleUi(tester);

      expect(find.text('1课 ¥180'), findsOneWidget);
      expect(find.text('2课 ¥360'), findsOneWidget);
      expect(find.text('4课 ¥720'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, '2课 ¥360'));
      await _settleUi(tester);

      final amountField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(amountField.controller?.text, '360');
    },
  );

  testWidgets('uses explicit student context even before student list loads', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = const [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: PaymentBottomSheet(
              studentId: 'student-1',
              studentName: 'Alice',
              pricePerClass: 180,
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.textContaining('Alice'), findsOneWidget);
    expect(find.text('1课 ¥180'), findsOneWidget);
  });

  testWidgets(
    'showStudentPaymentSheet resolves missing student metadata centrally',
    (tester) async {
      _FakeStudentNotifier.seededStudents = [_seededStudent];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(_FakeSettingsNotifier.new),
            studentProvider.overrideWith(_FakeStudentNotifier.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return FilledButton(
                    onPressed: () {
                      showStudentPaymentSheet(context, studentId: 'student-1');
                    },
                    child: const Text('打开'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await _settleUi(tester);

      await tester.tap(find.text('打开'));
      await _settleUi(tester);

      expect(find.textContaining('Alice'), findsOneWidget);
      expect(find.text('1课 ¥180'), findsOneWidget);
    },
  );
  testWidgets(
    'shows current and projected balance preview while entering payment',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(_FakeSettingsNotifier.new),
            attendanceDaoProvider.overrideWithValue(_FakeAttendanceDao()),
            paymentDaoProvider.overrideWithValue(_FakePaymentDao()),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(
              body: PaymentBottomSheet(
                studentId: 'student-1',
                studentName: 'Alice',
                pricePerClass: 100,
              ),
            ),
          ),
        ),
      );
      await _settleUi(tester);

      expect(find.text('当前'), findsOneWidget);
      expect(find.text('待缴 ¥200.00'), findsNWidgets(2));

      await tester.enterText(find.byType(TextFormField).first, '250');
      await _settleUi(tester);

      expect(find.text('缴费后'), findsOneWidget);
      expect(find.text('结余 ¥50.00'), findsOneWidget);
    },
  );

  testWidgets('shows quick chip to fill current due amount', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          attendanceDaoProvider.overrideWithValue(_FakeAttendanceDao()),
          paymentDaoProvider.overrideWithValue(_FakePaymentDao()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: PaymentBottomSheet(
              studentId: 'student-1',
              studentName: 'Alice',
              pricePerClass: 100,
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.text('补齐待缴 ¥200'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, '补齐待缴 ¥200'));
    await _settleUi(tester);

    final amountField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(amountField.controller?.text, '200');
  });
}

final _seededStudent = StudentWithMeta(
  const Student(
    id: 'student-1',
    name: 'Alice',
    parentName: 'Parent A',
    parentPhone: '13900000001',
    pricePerClass: 180,
    status: 'active',
    createdAt: 1,
    updatedAt: 1,
  ),
  null,
);

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<Map<String, String>> build() async => const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;
}

class _FakeAttendanceDao extends AttendanceDao {
  _FakeAttendanceDao() : super(DatabaseHelper.instance);

  @override
  Future<double> getTotalFeeByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async => 300;
}

class _FakePaymentDao extends PaymentDao {
  _FakePaymentDao() : super(DatabaseHelper.instance);

  @override
  Future<double> getTotalByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async => 100;
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}
