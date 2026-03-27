import 'package:calligraphy_assistant/core/models/qwen_vision_config.dart';
import 'package:calligraphy_assistant/core/providers/ai_provider.dart';
import 'package:calligraphy_assistant/core/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ai providers', () {
    test('qwen config falls back to defaults when values are blank', () {
      _FakeSettingsNotifier.seededSettings = const {
        QwenVisionConfig.settingApiKey: 'sk-test',
        QwenVisionConfig.settingBaseUrl: '   ',
        QwenVisionConfig.settingModel: '',
        QwenVisionConfig.settingSystemPrompt: '  ',
      };

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(qwenVisionConfigProvider);

      expect(config.apiKey, 'sk-test');
      expect(config.baseUrl, QwenVisionConfig.defaultBaseUrl);
      expect(config.model, QwenVisionConfig.defaultModel);
      expect(config.systemPrompt, QwenVisionConfig.defaultSystemPrompt);
    });

    test('gateway and service are null when api key is missing', () {
      _FakeSettingsNotifier.seededSettings = const {};

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(visionAnalysisGatewayProvider), isNull);
      expect(container.read(handwritingAnalysisServiceProvider), isNull);
    });

    test('gateway and service are available when api key is present', () {
      _FakeSettingsNotifier.seededSettings = const {
        QwenVisionConfig.settingApiKey: 'sk-test',
      };

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(visionAnalysisGatewayProvider), isNotNull);
      expect(container.read(handwritingAnalysisServiceProvider), isNotNull);
    });
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {};

  @override
  Future<Map<String, String>> build() async => seededSettings;
}
