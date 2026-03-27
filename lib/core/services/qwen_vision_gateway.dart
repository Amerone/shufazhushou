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
      throw const VisionAnalysisException('尚未配置 Qwen API Key');
    }

    final endpoint = Uri.tryParse(config.baseUrl);
    if (endpoint == null) {
      throw const VisionAnalysisException('Qwen 端点地址无效');
    }

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
            'Qwen 请求失败，HTTP ${httpResponse.statusCode}';
        throw VisionAnalysisException(message);
      }

      final text = extractText(decoded);
      if (text.isEmpty) {
        throw const VisionAnalysisException('Qwen 返回内容为空');
      }

      return VisionAnalysisResult(
        model: decoded['model'] as String? ?? config.model,
        text: text,
        raw: decoded,
      );
    } on VisionAnalysisException {
      rethrow;
    } on TimeoutException {
      throw const VisionAnalysisException('Qwen 请求超时，请稍后重试');
    } on SocketException {
      throw const VisionAnalysisException('无法连接到 Qwen 服务，请检查网络或端点配置');
    } on HandshakeException {
      throw const VisionAnalysisException('Qwen TLS 握手失败，请检查端点证书或代理设置');
    } on HttpException catch (error) {
      throw VisionAnalysisException('Qwen 请求异常: ${error.message}');
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

  static Future<String> normalizeImageSource(String imageSource) async {
    final trimmed = imageSource.trim();
    if (trimmed.isEmpty) {
      throw const VisionAnalysisException('图片来源不能为空');
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
      throw VisionAnalysisException('图片文件不存在: ${file.path}');
    }

    final bytes = await file.readAsBytes();
    final mimeType = _guessMimeType(file.path);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  static String extractText(Map<String, dynamic> response) {
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty) return '';

    final message = (choices.first as Map<String, dynamic>)['message'];
    if (message is! Map<String, dynamic>) return '';

    final content = message['content'];
    if (content is String) {
      return content.trim();
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is! Map<String, dynamic>) continue;
        final text = item['text'] as String?;
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
      throw const VisionAnalysisException('Qwen 返回了无法解析的 JSON 响应');
    }
    throw const VisionAnalysisException('Qwen 返回了无法识别的响应结构');
  }

  static String? _extractErrorMessage(Map<String, dynamic> response) {
    final error = response['error'];
    if (error is Map<String, dynamic>) {
      return error['message'] as String?;
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
}
