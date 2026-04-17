import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/class_template.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/class_template_provider.dart';
import 'package:moyun/core/providers/home_workbench_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/services/home_workbench_service.dart';
import 'package:moyun/features/home/screens/home_screen.dart';
import 'package:moyun/features/home/widgets/quick_entry_sheet.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  testWidgets('empty home state exposes setup guide entry', (tester) async {
    _setLargeHomeViewport(tester);
    _FakeSettingsNotifier.seededSettings = const {
      InteractionFeedback.hapticsEnabledKey: 'false',
      InteractionFeedback.soundEnabledKey: 'false',
    };
    _FakeStudentNotifier.seededStudents = const [];
    _FakeClassTemplateNotifier.seededTemplates = const [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
          attendanceProvider.overrideWith(_EmptyAttendanceNotifier.new),
          classTemplateProvider.overrideWith(_FakeClassTemplateNotifier.new),
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

  testWidgets(
    'home shows quick entry shortcuts for recent group and template',
    (tester) async {
      _setLargeHomeViewport(tester);
      _FakeSettingsNotifier.seededSettings = const {
        InteractionFeedback.hapticsEnabledKey: 'false',
        InteractionFeedback.soundEnabledKey: 'false',
        quickEntryDefaultStartTimeSettingKey: '18:00',
        quickEntryDefaultEndTimeSettingKey: '19:30',
        quickEntryDefaultStatusSettingKey: 'present',
        quickEntryRecentStudentIdsSettingKey: 'student-1,student-2',
      };
      _FakeStudentNotifier.seededStudents = [
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
          '2026-04-01',
        ),
        StudentWithMeta(
          const Student(
            id: 'student-2',
            name: 'Bob',
            parentName: 'Parent B',
            parentPhone: '13900000002',
            pricePerClass: 180,
            status: 'active',
            createdAt: 2,
            updatedAt: 2,
          ),
          '2026-04-01',
        ),
      ];
      _FakeClassTemplateNotifier.seededTemplates = const [
        ClassTemplate(
          id: 'template-1',
          name: '晚班',
          startTime: '18:00',
          endTime: '19:30',
          createdAt: 1,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(_FakeSettingsNotifier.new),
            studentProvider.overrideWith(_FakeStudentNotifier.new),
            attendanceProvider.overrideWith(_EmptyAttendanceNotifier.new),
            classTemplateProvider.overrideWith(_FakeClassTemplateNotifier.new),
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
              ],
            ),
          ),
        ),
      );
      await _settleUi(tester);

      expect(find.text('常用记课捷径'), findsOneWidget);
      expect(find.text('按最近班级记课'), findsOneWidget);
      expect(find.text('晚班'), findsOneWidget);
      expect(find.text('18:00-19:30'), findsWidgets);
    },
  );

  testWidgets('home places attendance list before calendar', (tester) async {
    _setLargeHomeViewport(tester);

    _FakeSettingsNotifier.seededSettings = const {
      InteractionFeedback.hapticsEnabledKey: 'false',
      InteractionFeedback.soundEnabledKey: 'false',
    };
    _FakeStudentNotifier.seededStudents = [
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
        '2026-04-01',
      ),
    ];
    _FakeClassTemplateNotifier.seededTemplates = const [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          studentProvider.overrideWith(_FakeStudentNotifier.new),
          attendanceProvider.overrideWith(_EmptyAttendanceNotifier.new),
          classTemplateProvider.overrideWith(_FakeClassTemplateNotifier.new),
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
            ],
          ),
        ),
      ),
    );
    await _settleUi(tester);

    final calendarTop = tester.getTopLeft(find.text('本月课历')).dy;
    final attendanceTop = tester
        .getTopLeft(find.textContaining('出勤名单').first)
        .dy;

    expect(attendanceTop, lessThan(calendarTop));
  });
}

void _setLargeHomeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };

  @override
  Future<Map<String, String>> build() async => seededSettings;
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;
}

class _EmptyAttendanceNotifier extends MonthAttendanceNotifier {
  @override
  Future<List<Attendance>> build() async => const [];
}

class _FakeClassTemplateNotifier extends ClassTemplateNotifier {
  static List<ClassTemplate> seededTemplates = const [];

  @override
  Future<List<ClassTemplate>> build() async => seededTemplates;
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}
