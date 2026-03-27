import 'package:calligraphy_assistant/core/models/qwen_vision_config.dart';
import 'package:calligraphy_assistant/core/providers/ai_provider.dart';
import 'package:calligraphy_assistant/core/providers/settings_provider.dart';
import 'package:calligraphy_assistant/core/services/handwriting_analysis_service.dart';
import 'package:calligraphy_assistant/core/services/vision_analysis_gateway.dart';
import 'package:calligraphy_assistant/features/settings/screens/ai_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ai settings route renders workbench and executes analysis', (
    tester,
  ) async {
    final gateway = _FakeVisionGateway();
    _FakeSettingsNotifier.seededSettings = const {
      QwenVisionConfig.settingApiKey: 'sk-test',
      QwenVisionConfig.settingModel: 'qwen3-vl-plus',
    };

    final router = GoRouter(
      initialLocation: '/settings/ai',
      routes: [
        GoRoute(
          path: '/settings/ai',
          builder: (context, state) => const AiSettingsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          handwritingAnalysisServiceProvider.overrideWithValue(
            HandwritingAnalysisService(gateway: gateway),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await _settleUi(tester);

    expect(find.text('AI 视觉'), findsOneWidget);
    expect(find.text('调试调用'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('ai_image_source_field')),
      'https://example.com/ink-work.png',
    );
    await tester.tap(find.byKey(const ValueKey('run_qwen_analysis_button')));
    await _settleUi(tester);
    await tester.tap(find.text('确认'));
    await _settleUi(tester);

    expect(gateway.lastRequest, isNotNull);
    expect(gateway.lastRequest!.imageSource, 'https://example.com/ink-work.png');
    expect(find.byKey(const ValueKey('ai_analysis_result_text')), findsOneWidget);
    expect(find.textContaining('结构化结果 · qwen3-vl-plus'), findsOneWidget);
    expect(find.text('集成测试结构化结果'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai_analysis_suggestion_0')), findsOneWidget);
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {};

  @override
  Future<Map<String, String>> build() async => seededSettings;
}

class _FakeVisionGateway implements VisionAnalysisGateway {
  VisionAnalysisRequest? lastRequest;

  @override
  Future<VisionAnalysisResult> analyze(VisionAnalysisRequest request) async {
    lastRequest = request;
    return const VisionAnalysisResult(
      model: 'qwen3-vl-plus',
      text: '''
{
  "summary": "集成测试结构化结果",
  "stroke_observation": "起笔较稳。",
  "structure_observation": "中宫收束较好。",
  "layout_observation": "章法节奏自然。",
  "practice_suggestions": ["保持单字慢练", "强化字距控制"]
}
''',
      raw: <String, dynamic>{},
    );
  }
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
