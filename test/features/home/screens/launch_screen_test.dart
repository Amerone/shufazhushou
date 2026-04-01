import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/home/screens/launch_screen.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  testWidgets('tap skip opens setup when there are no students', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = const [];

    await _pumpLaunchScreen(tester);

    await tester.tap(find.byType(GestureDetector).first);
    await _settleUi(tester);

    expect(find.text('setup'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  testWidgets('completed animation opens home when students already exist', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = [_seededStudent];

    await _pumpLaunchScreen(tester);
    await tester.pump(const Duration(milliseconds: 3600));
    await _settleUi(tester);

    expect(find.text('home'), findsOneWidget);
    expect(find.text('setup'), findsNothing);
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
  '2026-03-30',
);

Future<void> _pumpLaunchScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        studentProvider.overrideWith(_FakeStudentNotifier.new),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: GoRouter(
          initialLocation: '/launch',
          routes: [
            GoRoute(
              path: '/launch',
              builder: (context, state) => const LaunchScreen(),
            ),
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('home'))),
            ),
            GoRoute(
              path: '/setup',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('setup'))),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

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
