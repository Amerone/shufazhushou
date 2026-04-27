import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/app.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/shared/constants.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  testWidgets('app bootstrap renders launch route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    expect(find.text(kDefaultInstitutionName), findsWidgets);
    expect(find.bySemanticsLabel('跳过开屏动画'), findsOneWidget);
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<Map<String, String>> build() async => const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };

  @override
  Future<void> set(String key, String value) async {
    state = AsyncData({...?state.valueOrNull, key: value});
  }
}

class _FakeStudentNotifier extends StudentNotifier {
  @override
  Future<List<StudentWithMeta>> build() async => [
    StudentWithMeta(
      const Student(
        id: 'student-1',
        name: '测试学员',
        pricePerClass: 180,
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
      ),
      '2026-04-01',
    ),
  ];
}
