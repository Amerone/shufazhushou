import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/providers/package_info_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/features/settings/screens/settings_screen.dart';
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
  });

  testWidgets('settings screen renders overview progress and shortcuts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    expect(find.text('配置完成度'), findsOneWidget);
    expect(find.text('4/4 项已就绪'), findsOneWidget);
    expect(find.byIcon(Icons.backup_outlined), findsWidgets);
    expect(find.byIcon(Icons.draw_outlined), findsWidgets);
    expect(find.byIcon(Icons.view_quilt_outlined), findsWidgets);
    expect(find.byIcon(Icons.psychology_alt_outlined), findsWidgets);
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {};

  @override
  Future<Map<String, String>> build() async => seededSettings;

  @override
  Future<void> set(String key, String value) async {
    seededSettings = {...seededSettings, key: value};
    state = AsyncData(seededSettings);
  }
}
