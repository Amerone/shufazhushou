import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/qwen_vision_config.dart';
import 'package:moyun/core/services/qwen_vision_gateway.dart';
import 'package:moyun/core/services/vision_analysis_gateway.dart';

void main() {
  group('QwenVisionConfig', () {
    test('uses defaults when optional settings are missing', () {
      final config = QwenVisionConfig.fromSettings(const {
        QwenVisionConfig.settingApiKey: 'sk-test',
      });

      expect(config.apiKey, 'sk-test');
      expect(config.baseUrl, QwenVisionConfig.defaultBaseUrl);
      expect(config.model, QwenVisionConfig.defaultModel);
      expect(config.systemPrompt, isNotEmpty);
    });

    test('treats insecure remote http endpoints as invalid', () {
      const config = QwenVisionConfig(
        apiKey: 'sk-test',
        baseUrl: 'http://example.com/v1/chat/completions',
        model: 'qwen3-vl-plus',
        systemPrompt: 'analyze text',
      );

      expect(config.hasApiKey, isTrue);
      expect(config.hasValidBaseUrl, isFalse);
      expect(config.isConfigured, isFalse);
      expect(
        QwenVisionConfig.validateBaseUrl(config.baseUrl),
        QwenVisionConfig.insecureBaseUrlMessage,
      );
    });

    test('allows local http endpoints for debug-only testing', () {
      expect(QwenVisionConfig.validateBaseUrl('http://127.0.0.1:8080'), isNull);
    });

    test('rejects non-official https endpoints by default', () {
      const config = QwenVisionConfig(
        apiKey: 'sk-test',
        baseUrl: 'https://example.com/v1/chat/completions',
        model: 'qwen3-vl-plus',
        systemPrompt: 'analyze text',
      );

      expect(config.hasValidBaseUrl, isFalse);
      expect(
        QwenVisionConfig.validateBaseUrl(config.baseUrl),
        QwenVisionConfig.restrictedBaseUrlMessage,
      );
    });

    test(
      'allows non-official https endpoints when advanced mode is enabled',
      () {
        const config = QwenVisionConfig(
          apiKey: 'sk-test',
          baseUrl: 'https://example.com/v1/chat/completions',
          model: 'qwen3-vl-plus',
          systemPrompt: 'analyze text',
          allowCustomEndpoint: true,
        );

        expect(config.hasValidBaseUrl, isTrue);
        expect(
          QwenVisionConfig.validateBaseUrl(
            config.baseUrl,
            allowCustomEndpoint: true,
          ),
          isNull,
        );
      },
    );
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
      final userMessage =
          (payload['messages'] as List)[1] as Map<String, dynamic>;
      final content = userMessage['content'] as List;
      expect(
        (content[0] as Map<String, dynamic>)['text'],
        'summarize this homework image',
      );
      expect(
        ((content[1] as Map<String, dynamic>)['image_url']
            as Map<String, dynamic>)['url'],
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
      const request = TextAnalysisRequest(prompt: 'summarize recent progress');

      final payload = await QwenVisionGateway.buildTextPayload(
        config: config,
        request: request,
      );

      expect(payload['model'], 'qwen3-vl-plus');
      expect(payload['stream'], isFalse);
      expect(payload['messages'], hasLength(2));
      expect((payload['messages'] as List).last, {
        'role': 'user',
        'content': 'summarize recent progress',
      });
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
              'message': {'content': 'analysis done'},
            },
          ],
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
                ],
              },
            },
          ],
        }),
        'first line\nsecond line',
      );
    });

    test('analyzeText rejects requests when API key is missing', () async {
      const config = QwenVisionConfig(
        apiKey: '',
        baseUrl: QwenVisionConfig.defaultBaseUrl,
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

    test('analyzeText rejects insecure non-local http endpoints', () async {
      final gateway = QwenVisionGateway(
        config: const QwenVisionConfig(
          apiKey: 'sk-test',
          baseUrl: 'http://example.com/v1/chat/completions',
          model: 'qwen3-vl-plus',
          systemPrompt: 'analyze text',
        ),
        httpClient: _FakeHttpClient(
          onPostUrl: (_) async => throw StateError('Should not be called'),
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
            QwenVisionConfig.insecureBaseUrlMessage,
          ),
        ),
      );
    });

    test(
      'analyzeText surfaces server error message from response body',
      () async {
        final gateway = _createGateway(
          httpClient: _responseClient(
            statusCode: 500,
            body: {
              'error': {'message': 'bad key'},
            },
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

    test(
      'analyzeText falls back to HTTP status when error message is missing',
      () async {
        final gateway = _createGateway(
          httpClient: _responseClient(statusCode: 500, body: const {}),
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

    test('analyzeText reports malformed JSON responses', () async {
      final gateway = _createGateway(
        httpClient: _responseClient(statusCode: 200, body: 'oops'),
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
    });

    test('analyzeText reports unsupported response structures', () async {
      final gateway = _createGateway(
        httpClient: _responseClient(statusCode: 200, body: const []),
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
    });

    test('analyzeText reports empty text responses', () async {
      final gateway = _createGateway(
        httpClient: _responseClient(
          statusCode: 200,
          body: {
            'choices': [
              {
                'message': {'content': ''},
              },
            ],
          },
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
    });

    test(
      'analyzeText maps socket exceptions to a user-friendly message',
      () async {
        final gateway = _createGateway(
          httpClient: _FakeHttpClient(
            onPostUrl: (_) async => throw SocketException('Connection refused'),
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
      },
    );
  });
}

QwenVisionGateway _createGateway({
  required HttpClient httpClient,
  String baseUrl = QwenVisionConfig.defaultBaseUrl,
}) {
  return QwenVisionGateway(
    config: QwenVisionConfig(
      apiKey: 'sk-test',
      baseUrl: baseUrl,
      model: 'qwen3-vl-plus',
      systemPrompt: 'analyze text',
    ),
    httpClient: httpClient,
  );
}

HttpClient _responseClient({required int statusCode, required Object body}) {
  return _FakeHttpClient(
    onPostUrl: (url) async {
      expect(url.scheme, 'https');
      return _FakeHttpClientRequest(
        onClose: (bodyBytes, headers) async {
          expect(
            headers.values[HttpHeaders.authorizationHeader],
            'Bearer sk-test',
          );
          expect(
            headers.values[HttpHeaders.contentTypeHeader],
            'application/json',
          );
          final payload =
              jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
          expect(payload['model'], 'qwen3-vl-plus');
          expect(payload['messages'], isNotEmpty);
          return _FakeHttpClientResponse(statusCode: statusCode, body: body);
        },
      );
    },
  );
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({required this.onPostUrl});

  final Future<HttpClientRequest> Function(Uri url) onPostUrl;

  @override
  Future<HttpClientRequest> postUrl(Uri url) => onPostUrl(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.onClose});

  final Future<HttpClientResponse> Function(
    List<int> bodyBytes,
    _FakeHttpHeaders headers,
  )
  onClose;
  final _bodyBytes = <int>[];
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
  }

  @override
  Future<HttpClientResponse> close() {
    return onClose(List<int>.unmodifiable(_bodyBytes), _headers);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final values = <String, Object>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({required this.statusCode, required Object body})
    : _stream = Stream<List<int>>.fromIterable([
        utf8.encode(body is String ? body : jsonEncode(body)),
      ]);

  final Stream<List<int>> _stream;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
