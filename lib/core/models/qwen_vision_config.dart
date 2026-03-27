class QwenVisionConfig {
  static const settingApiKey = 'qwen_api_key';
  static const settingBaseUrl = 'qwen_base_url';
  static const settingModel = 'qwen_model';
  static const settingSystemPrompt = 'qwen_system_prompt';

  static const defaultBaseUrl =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const defaultModel = 'qwen3-vl-plus';
  static const defaultSystemPrompt =
      '你是一名书法教学分析助手，请结合图片内容，从笔画、结构、章法和练习建议四个方面给出简洁、可执行的反馈。';

  final String apiKey;
  final String baseUrl;
  final String model;
  final String systemPrompt;

  const QwenVisionConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.systemPrompt,
  });

  factory QwenVisionConfig.fromSettings(Map<String, String> settings) {
    return QwenVisionConfig(
      apiKey: (settings[settingApiKey] ?? '').trim(),
      baseUrl: _readValue(settings, settingBaseUrl, defaultBaseUrl),
      model: _readValue(settings, settingModel, defaultModel),
      systemPrompt: _readValue(
        settings,
        settingSystemPrompt,
        defaultSystemPrompt,
      ),
    );
  }

  bool get isConfigured => apiKey.isNotEmpty;

  Map<String, String> toSettingsMap() {
    return {
      settingApiKey: apiKey,
      settingBaseUrl: baseUrl,
      settingModel: model,
      settingSystemPrompt: systemPrompt,
    };
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
}
