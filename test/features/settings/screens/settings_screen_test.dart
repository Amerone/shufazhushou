import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/providers/package_info_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/features/settings/screens/settings_screen.dart';
import 'package:moyun/features/settings/widgets/settings_text_edit_sheet.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    _FakeSettingsNotifier.seededSettings = const {
      'teacher_name': '王老师',
      'signature_path': '/tmp/signature.png',
      'default_message_template': '本月练习持续稳定。',
      'default_watermark_enabled': 'true',
      'last_backup_at': '4102444800000',
      InteractionFeedback.hapticsEnabledKey: 'false',
      InteractionFeedback.soundEnabledKey: 'false',
    };
    _FakeSettingsNotifier.pendingSave = null;
    _FakeSettingsNotifier.saveError = null;
    _FakeSettingsNotifier.setCallCount = 0;
  });

  testWidgets('settings screen renders overview progress and shortcuts', (
    tester,
  ) async {
    _setLargeViewport(tester);

    await _pumpScreen(tester);

    expect(find.text('配置完成度'), findsOneWidget);
    expect(find.text('4/4 项已就绪'), findsOneWidget);
    expect(find.byIcon(Icons.backup_outlined), findsWidgets);
    expect(find.byIcon(Icons.draw_outlined), findsWidgets);
    expect(find.byIcon(Icons.view_quilt_outlined), findsWidgets);
    expect(find.byIcon(Icons.psychology_alt_outlined), findsWidgets);
  });

  testWidgets('switch rows toggle from the full setting tile', (tester) async {
    _setLargeViewport(tester);

    await _pumpScreen(tester);

    final hapticsLabel = find.text('启用触感反馈');
    await tester.scrollUntilVisible(hapticsLabel, 400);
    await tester.tap(hapticsLabel);
    await tester.pumpAndSettle();

    expect(_FakeSettingsNotifier.setCallCount, 1);
    expect(
      _FakeSettingsNotifier.seededSettings[InteractionFeedback
          .hapticsEnabledKey],
      'true',
    );
  });

  testWidgets('developer tools stay hidden until version tapped five times', (
    tester,
  ) async {
    _setLargeViewport(tester);

    await _pumpScreen(tester);

    expect(find.text('开发者工具'), findsNothing);

    final versionLabel = find.textContaining('版本 1.2.3').last;
    await tester.scrollUntilVisible(versionLabel, 400);
    await Scrollable.ensureVisible(
      tester.element(versionLabel),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    final versionTile = find
        .ancestor(of: versionLabel, matching: find.byType(InkWell))
        .last;

    for (var i = 0; i < 4; i++) {
      await tester.tap(versionTile);
      await tester.pump();
    }

    expect(find.text('开发者工具'), findsNothing);

    await tester.tap(versionTile);
    await tester.pumpAndSettle();

    expect(find.text('开发者工具'), findsOneWidget);
    expect(find.text('生成测试数据'), findsOneWidget);
    expect(find.text('清空全部数据'), findsOneWidget);
  });

  testWidgets('text edit save is disabled while saving', (tester) async {
    _setLargeViewport(tester);
    final saveCompleter = Completer<void>();
    _FakeSettingsNotifier.pendingSave = saveCompleter;

    await _pumpScreen(tester);
    await _openTeacherNameSheet(tester);
    await tester.enterText(find.byType(TextField), '李老师');

    await tester.tap(find.text('保存修改'));
    await tester.pump();

    expect(_FakeSettingsNotifier.setCallCount, 1);
    expect(find.text('保存中...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '保存中...'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('保存中...'));
    await tester.pump();

    expect(_FakeSettingsNotifier.setCallCount, 1);

    saveCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('保存中...'), findsNothing);
    expect(_FakeSettingsNotifier.seededSettings['teacher_name'], '李老师');
  });

  testWidgets('text edit save failure keeps input and shows error', (
    tester,
  ) async {
    _setLargeViewport(tester);
    _FakeSettingsNotifier.saveError = Exception('boom');

    await _pumpScreen(tester);
    await _openTeacherNameSheet(tester);
    await tester.enterText(find.byType(TextField), '李老师');

    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '保存修改'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '李老师',
    );
    expect(_FakeSettingsNotifier.seededSettings['teacher_name'], '王老师');
  });
}

Future<void> _openTeacherNameSheet(WidgetTester tester) async {
  final teacherTile = find
      .ancestor(of: find.text('教师姓名'), matching: find.byType(InkWell))
      .first;
  await tester.tap(teacherTile);
  await tester.pumpAndSettle();
  expect(find.byType(SettingsTextEditSheet), findsOneWidget);
  expect(find.byType(TextField), findsOneWidget);
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        packageInfoProvider.overrideWith(
          (ref) => PackageInfo(
            appName: '墨韵',
            packageName: 'com.example.moyun',
            version: '1.2.3',
            buildNumber: '12',
          ),
        ),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {};
  static Completer<void>? pendingSave;
  static Object? saveError;
  static int setCallCount = 0;

  @override
  Future<Map<String, String>> build() async => seededSettings;

  @override
  Future<void> set(String key, String value) async {
    setCallCount++;
    if (pendingSave case final completer?) {
      await completer.future;
    }
    if (saveError case final error?) {
      throw error;
    }
    seededSettings = {...seededSettings, key: value};
    state = AsyncData(seededSettings);
  }
}
