import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/qwen_vision_config.dart';
import 'vision_analysis_gateway.dart';

class QwenVisionGateway implements VisionAnalysisGateway {
  static const _requestTimeout = Duration(seconds: 30);

  final QwenVisionConfig config;
  final HttpClient _httpClient;

  QwenVisionGateway({
    required this.config,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  void dispose() {
    _httpClient.close(force: true);
  }

  @override
  Future<VisionAnalysisResult> analyze(VisionAnalysisRequest request) async {
    if (!config.isConfigured) {
      throw const VisionAnalysisException(
        'Qwen API key is not configured.',
      );
    }

    final endpoint = _resolveEndpoint(config.baseUrl);

    try {
      final payload = await buildPayload(
        config: config,
        request: request,
      );

      final httpRequest = await _httpClient
          .postUrl(endpoint)
          .timeout(_requestTimeout);
      httpRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${config.apiKey}',
      );
      httpRequest.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json',
      );
      httpRequest.add(utf8.encode(jsonEncode(payload)));

      final httpResponse = await httpRequest.close().timeout(_requestTimeout);
      final body = await httpResponse
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);
      final decoded = _decodeBody(body);

      if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
        final message = _extractErrorMessage(decoded) ??
            'Qwen request failed with HTTP ${httpResponse.statusCode}.';
        throw VisionAnalysisException(message);
      }

      final text = extractText(decoded);
      if (text.isEmpty) {
        throw const VisionAnalysisException('Qwen returned an empty response.');
      }

      return VisionAnalysisResult(
        model: decoded['model'] as String? ?? config.model,
        text: text,
        raw: decoded,
      );
    } on VisionAnalysisException {
      rethrow;
    } on TimeoutException {
      throw const VisionAnalysisException(
        'Qwen request timed out. Please try again later.',
      );
    } on SocketException {
      throw const VisionAnalysisException(
        'Unable to connect to Qwen. Check the network or endpoint settings.',
      );
    } on HandshakeException {
      throw const VisionAnalysisException(
        'Qwen TLS handshake failed. Check the endpoint certificate or proxy.',
      );
    } on HttpException catch (error) {
      throw VisionAnalysisException('Qwen HTTP error: ${error.message}');
    } on ArgumentError catch (error) {
      throw VisionAnalysisException('Invalid Qwen request: ${error.message}');
    }
  }

  @override
  Future<VisionAnalysisResult> analyzeText(TextAnalysisRequest request) async {
    if (!config.isConfigured) {
      throw const VisionAnalysisException(
        'Qwen API key is not configured.',
      );
    }

    final endpoint = _resolveEndpoint(config.baseUrl);

    try {
      final payload = await buildTextPayload(
        config: config,
        request: request,
      );

      final httpRequest = await _httpClient
          .postUrl(endpoint)
          .timeout(_requestTimeout);
      httpRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${config.apiKey}',
      );
      httpRequest.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json',
      );
      httpRequest.add(utf8.encode(jsonEncode(payload)));

      final httpResponse = await httpRequest.close().timeout(_requestTimeout);
      final body = await httpResponse
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);
      final decoded = _decodeBody(body);

      if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
        final message = _extractErrorMessage(decoded) ??
            'Qwen request failed with HTTP ${httpResponse.statusCode}.';
        throw VisionAnalysisException(message);
      }

      final text = extractText(decoded);
      if (text.isEmpty) {
        throw const VisionAnalysisException('Qwen returned an empty response.');
      }

      return VisionAnalysisResult(
        model: decoded['model'] as String? ?? config.model,
        text: text,
        raw: decoded,
      );
    } on VisionAnalysisException {
      rethrow;
    } on TimeoutException {
      throw const VisionAnalysisException(
        'Qwen request timed out. Please try again later.',
      );
    } on SocketException {
      throw const VisionAnalysisException(
        'Unable to connect to Qwen. Check the network or endpoint settings.',
      );
    } on HandshakeException {
      throw const VisionAnalysisException(
        'Qwen TLS handshake failed. Check the endpoint certificate or proxy.',
      );
    } on HttpException catch (error) {
      throw VisionAnalysisException('Qwen HTTP error: ${error.message}');
    } on ArgumentError catch (error) {
      throw VisionAnalysisException('Invalid Qwen request: ${error.message}');
    }
  }

  static Future<Map<String, dynamic>> buildPayload({
    required QwenVisionConfig config,
    required VisionAnalysisRequest request,
  }) async {
    final normalizedImage = await normalizeImageSource(request.imageSource);
    final messages = <Map<String, dynamic>>[];

    if (config.systemPrompt.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': config.systemPrompt,
      });
    }

    messages.add({
      'role': 'user',
      'content': [
        {
          'type': 'text',
          'text': request.prompt,
        },
        {
          'type': 'image_url',
          'image_url': {'url': normalizedImage},
        },
      ],
    });

    return {
      'model': config.model,
      'messages': messages,
      'temperature': request.temperature,
      'stream': false,
    };
  }

  static Future<Map<String, dynamic>> buildTextPayload({
    required QwenVisionConfig config,
    required TextAnalysisRequest request,
  }) async {
    final prompt = request.prompt.trim();
    if (prompt.isEmpty) {
      throw const VisionAnalysisException('Text prompt cannot be empty.');
    }

    final messages = <Map<String, dynamic>>[];

    if (config.systemPrompt.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': config.systemPrompt,
      });
    }

    messages.add({
      'role': 'user',
      'content': prompt,
    });

    return {
      'model': config.model,
      'messages': messages,
      'temperature': request.temperature,
      'stream': false,
    };
  }

  static Future<String> normalizeImageSource(String imageSource) async {
    final trimmed = imageSource.trim();
    if (trimmed.isEmpty) {
      throw const VisionAnalysisException('Image source cannot be empty.');
    }

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    final file = uri != null && uri.scheme == 'file'
        ? File.fromUri(uri)
        : File(trimmed);
    if (!await file.exists()) {
      throw VisionAnalysisException(
        'Image file does not exist: ${file.path}',
      );
    }

    final bytes = await file.readAsBytes();
    final mimeType = _guessMimeType(file.path);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  static String extractText(Map<String, dynamic> response) {
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty) return '';

    final firstChoice = choices.first;
    if (firstChoice is! Map) return '';

    final message = firstChoice['message'];
    if (message is! Map) return '';

    final content = message['content'];
    if (content is String) {
      return content.trim();
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is! Map) continue;
        final text = item['text']?.toString();
        if (text == null || text.trim().isEmpty) continue;
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write(text.trim());
      }
      return buffer.toString().trim();
    }
    return '';
  }

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      throw const VisionAnalysisException(
        'Qwen returned malformed JSON.',
      );
    }
    throw const VisionAnalysisException(
      'Qwen returned an unsupported response structure.',
    );
  }

  static String? _extractErrorMessage(Map<String, dynamic> response) {
    final error = response['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      final normalized = message?.toString().trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  static String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  static Uri _resolveEndpoint(String baseUrl) {
    final endpoint = Uri.tryParse(baseUrl.trim());
    if (endpoint == null ||
        !endpoint.isAbsolute ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      throw const VisionAnalysisException('Qwen endpoint URL is invalid.');
    }
    return endpoint;
  }
}