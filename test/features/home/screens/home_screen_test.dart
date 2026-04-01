import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/home_workbench_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/services/home_workbench_service.dart';
import 'package:moyun/features/home/screens/home_screen.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  testWidgets('empty home state exposes setup guide entry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_EmptyStudentNotifier.new),
          attendanceProvider.overrideWith(_EmptyAttendanceNotifier.new),
          homeWorkbenchProvider.overrideWith(
            (ref) async => const <HomeWorkbenchTask>[],
          ),
        ],
        child: MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
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
    await _settleUi(tester);

    expect(find.text('查看开课引导'), findsOneWidget);

    await tester.tap(find.text('查看开课引导'));
    await _settleUi(tester);

    expect(find.text('setup'), findsOneWidget);
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<Map<String, String>> build() async => const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };
}

class _EmptyStudentNotifier extends StudentNotifier {
  @override
  Future<List<StudentWithMeta>> build() async => const [];
}

class _EmptyAttendanceNotifier extends MonthAttendanceNotifier {
  @override
  Future<List<Attendance>> build() async => const [];
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}
