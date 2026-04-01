import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/qwen_vision_config.dart';
import 'package:moyun/core/providers/ai_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';

void main() {
  group('ai providers', () {
    test('qwen config falls back to defaults when values are blank', () async {
      _FakeSettingsNotifier.seededSettings = const {
        QwenVisionConfig.settingApiKey: 'sk-test',
        QwenVisionConfig.settingBaseUrl: '   ',
        QwenVisionConfig.settingModel: '',
        QwenVisionConfig.settingSystemPrompt: '  ',
      };

      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.future);
      final config = container.read(qwenVisionConfigProvider);

      expect(config.apiKey, 'sk-test');
      expect(config.baseUrl, QwenVisionConfig.defaultBaseUrl);
      expect(config.model, QwenVisionConfig.defaultModel);
      expect(config.systemPrompt, QwenVisionConfig.defaultSystemPrompt);
    });

    test('gateway and services are null when api key is missing', () async {
      _FakeSettingsNotifier.seededSettings = const {};

      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.future);
      expect(container.read(visionAnalysisGatewayProvider), isNull);
      expect(container.read(handwritingAnalysisServiceProvider), isNull);
      expect(container.read(progressAnalysisServiceProvider), isNull);
      expect(container.read(dataInsightServiceProvider), isNull);
      expect(container.read(studentInsightAnalysisServiceProvider), isNull);
    });

    test('student name outbound switch defaults to false', () async {
      _FakeSettingsNotifier.seededSettings = const {};

      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.future);
      expect(container.read(aiIncludeStudentNameProvider), isFalse);
    });

    test('student name outbound switch reads persisted setting', () async {
      _FakeSettingsNotifier.seededSettings = const {
        QwenVisionConfig.settingIncludeStudentName: 'true',
      };

      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.future);
      expect(container.read(aiIncludeStudentNameProvider), isTrue);
    });

    test(
      'gateway and services are available when api key is present',
      () async {
        _FakeSettingsNotifier.seededSettings = const {
          QwenVisionConfig.settingApiKey: 'sk-test',
        };

        final container = ProviderContainer(
          overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
        );
        addTearDown(container.dispose);

        await container.read(settingsProvider.future);
        expect(container.read(visionAnalysisGatewayProvider), isNotNull);
        expect(container.read(handwritingAnalysisServiceProvider), isNotNull);
        expect(container.read(progressAnalysisServiceProvider), isNotNull);
        expect(container.read(dataInsightServiceProvider), isNotNull);
        expect(
          container.read(studentInsightAnalysisServiceProvider),
          isNotNull,
        );
      },
    );

    test(
      'gateway and services stay unavailable for insecure non-local http endpoints',
      () async {
        _FakeSettingsNotifier.seededSettings = const {
          QwenVisionConfig.settingApiKey: 'sk-test',
          QwenVisionConfig.settingBaseUrl:
              'http://example.com/v1/chat/completions',
        };

        final container = ProviderContainer(
          overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
        );
        addTearDown(container.dispose);

        await container.read(settingsProvider.future);
        final config = container.read(qwenVisionConfigProvider);

        expect(config.hasApiKey, isTrue);
        expect(config.hasValidBaseUrl, isFalse);
        expect(container.read(visionAnalysisGatewayProvider), isNull);
        expect(container.read(handwritingAnalysisServiceProvider), isNull);
        expect(container.read(progressAnalysisServiceProvider), isNull);
        expect(container.read(dataInsightServiceProvider), isNull);
        expect(container.read(studentInsightAnalysisServiceProvider), isNull);
      },
    );

    test(
      'gateway and services stay unavailable for non-official https endpoints by default',
      () async {
        _FakeSettingsNotifier.seededSettings = const {
          QwenVisionConfig.settingApiKey: 'sk-test',
          QwenVisionConfig.settingBaseUrl:
              'https://example.com/v1/chat/completions',
        };

        final container = ProviderContainer(
          overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
        );
        addTearDown(container.dispose);

        await container.read(settingsProvider.future);
        final config = container.read(qwenVisionConfigProvider);

        expect(config.hasApiKey, isTrue);
        expect(config.allowCustomEndpoint, isFalse);
        expect(config.hasValidBaseUrl, isFalse);
        expect(container.read(visionAnalysisGatewayProvider), isNull);
      },
    );

    test(
      'gateway and services are available for custom https endpoints when advanced mode is enabled',
      () async {
        _FakeSettingsNotifier.seededSettings = const {
          QwenVisionConfig.settingApiKey: 'sk-test',
          QwenVisionConfig.settingBaseUrl:
              'https://example.com/v1/chat/completions',
          QwenVisionConfig.settingAllowCustomEndpoint: 'true',
        };

        final container = ProviderContainer(
          overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
        );
        addTearDown(container.dispose);

        await container.read(settingsProvider.future);
        final config = container.read(qwenVisionConfigProvider);

        expect(config.allowCustomEndpoint, isTrue);
        expect(config.hasValidBaseUrl, isTrue);
        expect(container.read(visionAnalysisGatewayProvider), isNotNull);
      },
    );
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {};

  @override
  Future<Map<String, String>> build() async => seededSettings;
}
