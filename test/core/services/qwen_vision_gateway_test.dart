import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/qwen_vision_config.dart';
import 'package:moyun/core/services/qwen_vision_gateway.dart';
import 'package:moyun/core/services/vision_analysis_gateway.dart';

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
        systemPrompt: 'analyze image',
      );
      const request = VisionAnalysisRequest(
        prompt: 'summarize this homework image',
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
      expect((content[0] as Map<String, dynamic>)['text'], 'summarize this homework image');
      expect(
        ((content[1] as Map<String, dynamic>)['image_url'] as Map<String, dynamic>)['url'],
        'https://example.com/work.png',
      );
    });

    test('builds text-only payload without image content', () async {
      const config = QwenVisionConfig(
        apiKey: 'sk-test',
        baseUrl: QwenVisionConfig.defaultBaseUrl,
        model: 'qwen3-vl-plus',
        systemPrompt: 'analyze text',
      );
      const request = TextAnalysisRequest(
        prompt: 'summarize recent progress',
      );

      final payload = await QwenVisionGateway.buildTextPayload(
        config: config,
        request: request,
      );

      expect(payload['model'], 'qwen3-vl-plus');
      expect(payload['stream'], isFalse);
      expect(payload['messages'], hasLength(2));
      expect(
        (payload['messages'] as List).last,
        {
          'role': 'user',
          'content': 'summarize recent progress',
        },
      );
    });

    test('rejects empty text-only prompts', () async {
      const config = QwenVisionConfig(
        apiKey: 'sk-test',
        baseUrl: QwenVisionConfig.defaultBaseUrl,
        model: 'qwen3-vl-plus',
        systemPrompt: 'analyze text',
      );
      const request = TextAnalysisRequest(prompt: '   ');

      await expectLater(
        () => QwenVisionGateway.buildTextPayload(
          config: config,
          request: request,
        ),
        throwsA(
          isA<VisionAnalysisException>().having(
            (error) => error.message,
            'message',
            'Text prompt cannot be empty.',
          ),
        ),
      );
    });

    test('extracts text from string and list responses', () {
      expect(
        QwenVisionGateway.extractText({
          'choices': [
            {
              'message': {'content': 'analysis done'}
            }
          ]
        }),
        'analysis done',
      );

      expect(
        QwenVisionGateway.extractText({
          'choices': [
            {
              'message': {
                'content': [
                  {'text': 'first line'},
                  {'text': 'second line'},
                ]
              }
            }
          ]
        }),
        'first line\nsecond line',
      );
    });

    test('analyzeText rejects requests when API key is missing', () async {
      const config = QwenVisionConfig(
        apiKey: '',
        baseUrl: 'http://127.0.0.1:8080',
        model: 'qwen3-vl-plus',
        systemPrompt: 'analyze text',
      );
      final gateway = QwenVisionGateway(config: config);

      await expectLater(
        () => gateway.analyzeText(const TextAnalysisRequest(prompt: 'hello')),
        throwsA(
          isA<VisionAnalysisException>().having(
            (error) => error.message,
            'message',
            'Qwen API key is not configured.',
          ),
        ),
      );
    });

    test('analyzeText surfaces server error message from response body', () async {
      await _withTestServer(
        statusCode: 500,
        body: {
          'error': {'message': 'bad key'},
        },
        run: (baseUrl) async {
          final gateway = QwenVisionGateway(
            config: QwenVisionConfig(
              apiKey: 'sk-test',
              baseUrl: baseUrl,
              model: 'qwen3-vl-plus',
              systemPrompt: 'analyze text',
            ),
          );

          await expectLater(
            () => gateway.analyzeText(
              const TextAnalysisRequest(prompt: 'summarize progress'),
            ),
            throwsA(
              isA<VisionAnalysisException>().having(
                (error) => error.message,
                'message',
                'bad key',
              ),
            ),
          );
        },
      );
    });

    test('analyzeText falls back to HTTP status when error message is missing', () async {
      await _withTestServer(
        statusCode: 500,
        body: const {},
        run: (baseUrl) async {
          final gateway = QwenVisionGateway(
            config: QwenVisionConfig(
              apiKey: 'sk-test',
              baseUrl: baseUrl,
              model: 'qwen3-vl-plus',
              systemPrompt: 'analyze text',
            ),
          );

          await expectLater(
            () => gateway.analyzeText(
              const TextAnalysisRequest(prompt: 'summarize progress'),
            ),
            throwsA(
              isA<VisionAnalysisException>().having(
                (error) => error.message,
                'message',
                'Qwen request failed with HTTP 500.',
              ),
            ),
          );
        },
      );
    });

    test('analyzeText reports malformed JSON responses', () async {
      await _withTestServer(
        statusCode: 200,
        body: 'oops',
        run: (baseUrl) async {
          final gateway = QwenVisionGateway(
            config: QwenVisionConfig(
              apiKey: 'sk-test',
              baseUrl: baseUrl,
              model: 'qwen3-vl-plus',
              systemPrompt: 'analyze text',
            ),
          );

          await expectLater(
            () => gateway.analyzeText(
              const TextAnalysisRequest(prompt: 'summarize progress'),
            ),
            throwsA(
              isA<VisionAnalysisException>().having(
                (error) => error.message,
                'message',
                'Qwen returned malformed JSON.',
              ),
            ),
          );
        },
      );
    });

    test('analyzeText reports unsupported response structures', () async {
      await _withTestServer(
        statusCode: 200,
        body: const [],
        run: (baseUrl) async {
          final gateway = QwenVisionGateway(
            config: QwenVisionConfig(
              apiKey: 'sk-test',
              baseUrl: baseUrl,
              model: 'qwen3-vl-plus',
              systemPrompt: 'analyze text',
            ),
          );

          await expectLater(
            () => gateway.analyzeText(
              const TextAnalysisRequest(prompt: 'summarize progress'),
            ),
            throwsA(
              isA<VisionAnalysisException>().having(
                (error) => error.message,
                'message',
                'Qwen returned an unsupported response structure.',
              ),
            ),
          );
        },
      );
    });

    test('analyzeText reports empty text responses', () async {
      await _withTestServer(
        statusCode: 200,
        body: {
          'choices': [
            {
              'message': {'content': ''}
            },
          ],
        },
        run: (baseUrl) async {
          final gateway = QwenVisionGateway(
            config: QwenVisionConfig(
              apiKey: 'sk-test',
              baseUrl: baseUrl,
              model: 'qwen3-vl-plus',
              systemPrompt: 'analyze text',
            ),
          );

          await expectLater(
            () => gateway.analyzeText(
              const TextAnalysisRequest(prompt: 'summarize progress'),
            ),
            throwsA(
              isA<VisionAnalysisException>().having(
                (error) => error.message,
                'message',
                'Qwen returned an empty response.',
              ),
            ),
          );
        },
      );
    });

    test('analyzeText maps socket exceptions to a user-friendly message', () async {
      final reserved = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUrl = 'http://${reserved.address.address}:${reserved.port}';
      await reserved.close(force: true);

      final gateway = QwenVisionGateway(
        config: QwenVisionConfig(
          apiKey: 'sk-test',
          baseUrl: baseUrl,
          model: 'qwen3-vl-plus',
          systemPrompt: 'analyze text',
        ),
      );

      await expectLater(
        () => gateway.analyzeText(
          const TextAnalysisRequest(prompt: 'summarize progress'),
        ),
        throwsA(
          isA<VisionAnalysisException>().having(
            (error) => error.message,
            'message',
            'Unable to connect to Qwen. Check the network or endpoint settings.',
          ),
        ),
      );
    });
  });
}

Future<void> _withTestServer({
  required int statusCode,
  required Object body,
  required Future<void> Function(String baseUrl) run,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final requestFuture = server.first.then((request) async {
    request.response.statusCode = statusCode;
    if (body is String) {
      request.response.write(body);
    } else {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
    }
    await request.response.close();
  });

  try {
    await run('http://${server.address.address}:${server.port}');
    await requestFuture;
  } finally {
    await server.close(force: true);
  }
}
