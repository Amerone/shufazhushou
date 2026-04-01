import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/qwen_vision_config.dart';
import 'package:moyun/core/providers/ai_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/services/handwriting_analysis_service.dart';
import 'package:moyun/core/services/vision_analysis_gateway.dart';
import 'package:moyun/features/settings/screens/ai_settings_screen.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

void main() {
  setUp(() {
    _FakeSettingsNotifier.seededSettings = const {};
    _FakeSettingsNotifier.savedEntries.clear();
  });

  testWidgets('ai settings workbench omits student name by default', (
    tester,
  ) async {
    final gateway = _FakeVisionGateway();
    _FakeSettingsNotifier.seededSettings = const {
      QwenVisionConfig.settingApiKey: 'sk-test',
      QwenVisionConfig.settingModel: 'qwen3-vl-plus',
      InteractionFeedback.hapticsEnabledKey: 'false',
      InteractionFeedback.soundEnabledKey: 'false',
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          handwritingAnalysisServiceProvider.overrideWithValue(
            HandwritingAnalysisService(gateway: gateway),
          ),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await _settleUi(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ai_image_source_field')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai_image_source_field')),
      'https://example.com/work.jpg',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai_student_name_field')),
      'Li Si',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai_prompt_field')),
      'Focus on structure stability.',
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('run_qwen_analysis_button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('run_qwen_analysis_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(gateway.lastRequest, isNotNull);
    expect(gateway.lastRequest!.prompt, isNot(contains('Li Si')));
    expect(
      gateway.lastRequest!.prompt,
      contains('Focus on structure stability.'),
    );
    expect(
      find.byKey(const ValueKey('ai_analysis_result_card')),
      findsOneWidget,
    );
  });

  testWidgets('ai settings workbench can include student name when enabled', (
    tester,
  ) async {
    final gateway = _FakeVisionGateway();
    _FakeSettingsNotifier.seededSettings = const {
      QwenVisionConfig.settingApiKey: 'sk-test',
      QwenVisionConfig.settingModel: 'qwen3-vl-plus',
      QwenVisionConfig.settingIncludeStudentName: 'true',
      InteractionFeedback.hapticsEnabledKey: 'false',
      InteractionFeedback.soundEnabledKey: 'false',
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          handwritingAnalysisServiceProvider.overrideWithValue(
            HandwritingAnalysisService(
              gateway: gateway,
              includeStudentNameByDefault: true,
            ),
          ),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await _settleUi(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ai_image_source_field')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai_image_source_field')),
      'https://example.com/work.jpg',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai_student_name_field')),
      'Li Si',
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('run_qwen_analysis_button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('run_qwen_analysis_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(gateway.lastRequest, isNotNull);
    expect(gateway.lastRequest!.prompt, contains('Li Si'));
  });

  testWidgets('ai settings saves privacy toggle', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _FakeSettingsNotifier.seededSettings = const {
      QwenVisionConfig.settingApiKey: 'sk-test',
      InteractionFeedback.hapticsEnabledKey: 'false',
      InteractionFeedback.soundEnabledKey: 'false',
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          handwritingAnalysisServiceProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await _settleUi(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('ai_include_student_name_switch')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ai_include_student_name_switch')),
    );
    await tester.pumpAndSettle();

    expect(
      _FakeSettingsNotifier.savedEntries.any(
        (entry) =>
            entry.key == QwenVisionConfig.settingIncludeStudentName &&
            entry.value == 'true',
      ),
      isTrue,
    );
  });

  testWidgets(
    'ai settings rejects custom https endpoint before advanced mode is enabled',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _FakeSettingsNotifier.seededSettings = const {
        QwenVisionConfig.settingApiKey: 'sk-test',
        QwenVisionConfig.settingBaseUrl: QwenVisionConfig.defaultBaseUrl,
        InteractionFeedback.hapticsEnabledKey: 'false',
        InteractionFeedback.soundEnabledKey: 'false',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(_FakeSettingsNotifier.new),
            handwritingAnalysisServiceProvider.overrideWith((ref) => null),
          ],
          child: const MaterialApp(home: AiSettingsScreen()),
        ),
      );
      await _settleUi(tester);

      await tester.tap(find.byKey(const ValueKey('ai_setting_base_url_tile')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai_settings_edit_field')),
        'https://example.com/v1/chat/completions',
      );
      await tester.tap(find.byKey(const ValueKey('ai_settings_save_button')));
      await tester.pumpAndSettle();

      expect(
        find.text(AiSettingsScreen.restrictedEndpointMessage),
        findsOneWidget,
      );
      expect(_FakeSettingsNotifier.savedEntries, isEmpty);
    },
  );

  testWidgets('ai settings rejects insecure endpoints before saving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _FakeSettingsNotifier.seededSettings = const {
      QwenVisionConfig.settingApiKey: 'sk-test',
      QwenVisionConfig.settingBaseUrl: QwenVisionConfig.defaultBaseUrl,
      InteractionFeedback.hapticsEnabledKey: 'false',
      InteractionFeedback.soundEnabledKey: 'false',
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          handwritingAnalysisServiceProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await _settleUi(tester);

    await tester.tap(find.byKey(const ValueKey('ai_setting_base_url_tile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai_settings_edit_field')),
      'http://example.com/v1/chat/completions',
    );
    await tester.tap(find.byKey(const ValueKey('ai_settings_save_button')));
    await tester.pumpAndSettle();

    expect(find.text(AiSettingsScreen.insecureEndpointMessage), findsOneWidget);
    expect(_FakeSettingsNotifier.savedEntries, isEmpty);
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {};
  static final savedEntries = <MapEntry<String, String>>[];

  @override
  Future<Map<String, String>> build() async => seededSettings;

  @override
  Future<void> set(String key, String value) async {
    savedEntries.add(MapEntry(key, value));
    seededSettings = {...seededSettings, key: value};
    state = AsyncData(seededSettings);
  }
}

class _FakeVisionGateway implements VisionAnalysisGateway {
  VisionAnalysisRequest? lastRequest;

  @override
  Future<VisionAnalysisResult> analyze(VisionAnalysisRequest request) async {
    lastRequest = request;
    return const VisionAnalysisResult(
      model: 'qwen3-vl-plus',
      text: '{"summary":"solid overall structure"}',
      raw: <String, dynamic>{},
    );
  }

  @override
  Future<VisionAnalysisResult> analyzeText(TextAnalysisRequest request) async {
    throw const VisionAnalysisException(
      'Text analysis is not used in this test.',
    );
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
