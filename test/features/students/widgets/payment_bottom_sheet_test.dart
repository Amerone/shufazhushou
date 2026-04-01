import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/students/widgets/payment_bottom_sheet.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  testWidgets('quick amount chips fill payment field from class price', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = [_seededStudent];

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
            ),
          ),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.text('1节 ¥180'), findsOneWidget);
    expect(find.text('2节 ¥360'), findsOneWidget);
    expect(find.text('4节 ¥720'), findsOneWidget);

    final quickAmountChip = find.widgetWithText(ActionChip, '2节 ¥360');
    await tester.tap(quickAmountChip);
    await _settleUi(tester);

    final amountField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(amountField.controller?.text, '360');
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

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}
