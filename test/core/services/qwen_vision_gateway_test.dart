import 'package:calligraphy_assistant/core/models/qwen_vision_config.dart';
import 'package:calligraphy_assistant/core/services/qwen_vision_gateway.dart';
import 'package:calligraphy_assistant/core/services/vision_analysis_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QwenVisionConfig', () {
    test('uses defaults when optional settings are missing', () {
      final config = QwenVisionConfig.fromSettings(
        const {QwenVisionConfig.settingApiKey: 'sk-test'},
      );

      expect(config.apiKey, 'sk-test');
      expect(config.baseUrl, QwenVisionConfig.defaultBaseUrl);
      expect(config.model, QwenVisionConfig.defaultModel);
      expect(config.systemPrompt, isNotEmpty);
    });
  });

  group('QwenVisionGateway', () {
    test('builds dashscope-compatible payload', () async {
      const config = QwenVisionConfig(
        apiKey: 'sk-test',
        baseUrl: QwenVisionConfig.defaultBaseUrl,
        model: 'qwen3-vl-plus',
        systemPrompt: '请分析图片',
      );
      const request = VisionAnalysisRequest(
        prompt: '请总结这张作业图片',
        imageSource: 'https://example.com/work.png',
      );

      final payload = await QwenVisionGateway.buildPayload(
        config: config,
        request: request,
      );

      expect(payload['model'], 'qwen3-vl-plus');
      expect(payload['stream'], isFalse);
      expect(payload['messages'], hasLength(2));
      final userMessage = (payload['messages'] as List)[1] as Map<String, dynamic>;
      final content = userMessage['content'] as List;
      expect((content[0] as Map<String, dynamic>)['text'], '请总结这张作业图片');
      expect(
        ((content[1] as Map<String, dynamic>)['image_url'] as Map<String, dynamic>)['url'],
        'https://example.com/work.png',
      );
    });

    test('extracts text from string and list responses', () {
      expect(
        QwenVisionGateway.extractText({
          'choices': [
            {
              'message': {'content': '分析完成'}
            }
          ]
        }),
        '分析完成',
      );

      expect(
        QwenVisionGateway.extractText({
          'choices': [
            {
              'message': {
                'content': [
                  {'text': '第一段'},
                  {'text': '第二段'},
                ]
              }
            }
          ]
        }),
        '第一段\n第二段',
      );
    });
  });
}
