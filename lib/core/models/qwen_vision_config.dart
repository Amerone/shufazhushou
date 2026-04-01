import 'package:flutter/foundation.dart';

class QwenVisionConfig {
  static const settingApiKey = 'qwen_api_key';
  static const settingBaseUrl = 'qwen_base_url';
  static const settingModel = 'qwen_model';
  static const settingSystemPrompt = 'qwen_system_prompt';
  static const settingIncludeStudentName = 'qwen_include_student_name';
  static const settingAllowCustomEndpoint = 'qwen_allow_custom_endpoint';

  static const defaultBaseUrl =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const defaultModel = 'qwen3-vl-plus';
  static const defaultSystemPrompt =
      'You are a calligraphy analysis assistant. Review the input carefully '
      'and provide concise, actionable feedback on stroke quality, structure, '
      'layout, and next practice steps.';
  static const invalidBaseUrlMessage = 'Qwen endpoint URL is invalid.';
  static const insecureBaseUrlMessage =
      'Qwen endpoint must use HTTPS. HTTP is only allowed for localhost debugging.';
  static const restrictedBaseUrlMessage =
      'Qwen endpoint must use the official DashScope host unless custom endpoint mode is enabled.';
  static const _officialHosts = {'dashscope.aliyuncs.com'};

  final String apiKey;
  final String baseUrl;
  final String model;
  final String systemPrompt;
  final bool allowCustomEndpoint;

  const QwenVisionConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.systemPrompt,
    this.allowCustomEndpoint = false,
  });

  factory QwenVisionConfig.fromSettings(Map<String, String> settings) {
    return QwenVisionConfig(
      apiKey: (settings[settingApiKey] ?? '').trim(),
      baseUrl: _readBaseUrl(settings),
      model: _readValue(settings, settingModel, defaultModel),
      systemPrompt: _readValue(
        settings,
        settingSystemPrompt,
        defaultSystemPrompt,
      ),
      allowCustomEndpoint: settings[settingAllowCustomEndpoint] == 'true',
    );
  }

  bool get hasApiKey => apiKey.isNotEmpty;

  bool get hasValidBaseUrl =>
      validateBaseUrl(baseUrl, allowCustomEndpoint: allowCustomEndpoint) ==
      null;

  bool get isConfigured => hasApiKey && hasValidBaseUrl;

  Map<String, String> toSettingsMap() {
    return {
      settingApiKey: apiKey,
      settingBaseUrl: baseUrl,
      settingModel: model,
      settingSystemPrompt: systemPrompt,
      settingAllowCustomEndpoint: allowCustomEndpoint.toString(),
    };
  }

  static String _readBaseUrl(Map<String, String> settings) {
    final value = settings[settingBaseUrl]?.trim();
    if (value == null || value.isEmpty) return defaultBaseUrl;
    return value;
  }

  static String _readValue(
    Map<String, String> settings,
    String key,
    String fallback,
  ) {
    final value = settings[key]?.trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  static String? validateBaseUrl(
    String baseUrl, {
    bool allowCustomEndpoint = false,
  }) {
    final endpoint = Uri.tryParse(baseUrl.trim());
    if (endpoint == null || !endpoint.isAbsolute || endpoint.host.isEmpty) {
      return invalidBaseUrlMessage;
    }

    final scheme = endpoint.scheme.toLowerCase();
    if (scheme == 'https') {
      if (allowCustomEndpoint || _officialHosts.contains(endpoint.host)) {
        return null;
      }
      return restrictedBaseUrlMessage;
    }
    if (scheme == 'http' && _allowsInsecureLoopback(endpoint)) return null;
    if (scheme == 'http') return insecureBaseUrlMessage;
    return invalidBaseUrlMessage;
  }

  static Uri? tryParseEndpoint(
    String baseUrl, {
    bool allowCustomEndpoint = false,
  }) {
    if (validateBaseUrl(baseUrl, allowCustomEndpoint: allowCustomEndpoint) !=
        null) {
      return null;
    }
    return Uri.parse(baseUrl.trim());
  }

  static Uri? tryParseSecureEndpoint(
    String baseUrl, {
    bool allowCustomEndpoint = false,
  }) => tryParseEndpoint(baseUrl, allowCustomEndpoint: allowCustomEndpoint);

  static bool _allowsInsecureLoopback(Uri endpoint) {
    if (!kDebugMode) return false;

    final host = endpoint.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2' ||
        host == '10.0.3.2';
  }
}
