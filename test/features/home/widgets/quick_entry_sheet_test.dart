import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/class_template.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/class_template_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/home/widgets/quick_entry_sheet.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  testWidgets('restores recent student group and remembered defaults', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1080, 2200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    _FakeStudentNotifier.seededStudents = _seededStudents;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
          classTemplateProvider.overrideWith(_FakeClassTemplateNotifier.new),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: QuickEntrySheet()),
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.text('恢复上次同班（2人）'), findsOneWidget);
    expect(find.textContaining('当前默认：18:00-19:30 / 迟到'), findsOneWidget);

    final restoreChip = find.widgetWithText(ActionChip, '恢复上次同班（2人）');
    await tester.tap(restoreChip);
    await _settleUi(tester);

    expect(find.text('已选 2'), findsOneWidget);
    expect(find.text('直接保存（2人 / ¥380）'), findsOneWidget);
  });
}

final _seededStudents = [
  StudentWithMeta(
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
  ),
  StudentWithMeta(
    const Student(
      id: 'student-2',
      name: 'Bob',
      parentName: 'Parent B',
      parentPhone: '13900000002',
      pricePerClass: 200,
      status: 'active',
      createdAt: 2,
      updatedAt: 2,
    ),
    null,
  ),
];

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<Map<String, String>> build() async => const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
    'quick_entry_default_start_time': '18:00',
    'quick_entry_default_end_time': '19:30',
    'quick_entry_default_status': 'late',
    'quick_entry_recent_student_ids': 'student-1,student-2',
  };
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;
}

class _FakeClassTemplateNotifier extends ClassTemplateNotifier {
  @override
  Future<List<ClassTemplate>> build() async => const [];
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}
