import 'package:calligraphy_assistant/core/models/qwen_vision_config.dart';
import 'package:calligraphy_assistant/core/providers/ai_provider.dart';
import 'package:calligraphy_assistant/core/providers/settings_provider.dart';
import 'package:calligraphy_assistant/core/services/handwriting_analysis_service.dart';
import 'package:calligraphy_assistant/core/services/vision_analysis_gateway.dart';
import 'package:calligraphy_assistant/features/settings/screens/ai_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ai settings workbench runs analysis and renders result', (
    tester,
  ) async {
    final gateway = _FakeVisionGateway();
    _FakeSettingsNotifier.seededSettings = const {
      QwenVisionConfig.settingApiKey: 'sk-test',
      QwenVisionConfig.settingModel: 'qwen3-vl-plus',
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          handwritingAnalysisServiceProvider.overrideWithValue(
            HandwritingAnalysisService(gateway: gateway),
          ),
        ],
        child: const MaterialApp(
          home: AiSettingsScreen(),
        ),
      ),
    );
    await _settleUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('ai_image_source_field')),
      'https://example.com/work.jpg',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai_student_name_field')),
      '李四',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai_prompt_field')),
      '请重点关注结构稳定性',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('run_qwen_analysis_button')),
    );
    await tester.tap(find.byKey(const ValueKey('run_qwen_analysis_button')));
    await _settleUi(tester);
    await tester.tap(find.text('确认'));
    await _settleUi(tester);

    expect(gateway.lastRequest, isNotNull);
    expect(gateway.lastRequest!.prompt, contains('学生：李四'));
    expect(gateway.lastRequest!.prompt, contains('补充要求：请重点关注结构稳定性'));
    expect(find.byKey(const ValueKey('ai_analysis_result_card')), findsOneWidget);
    expect(find.textContaining('结构化结果 · qwen3-vl-plus'), findsOneWidget);
    expect(find.text('总评'), findsOneWidget);
    expect(find.text('笔画观察'), findsOneWidget);
    expect(find.text('练习建议'), findsOneWidget);
    expect(find.text('整体节奏稳定，观察维度完整。'), findsOneWidget);
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
  "summary": "整体节奏稳定，观察维度完整。",
  "stroke_observation": "收笔动作比较清楚，起笔还能再稳一些。",
  "structure_observation": "字内重心较稳，局部比例尚可继续调整。",
  "layout_observation": "整体章法较均衡。",
  "practice_suggestions": ["先慢写横画 10 遍", "复盘每个字的重心位置"]
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
