import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/handwriting_analysis_result.dart';
import '../../../core/models/qwen_vision_config.dart';
import '../../../core/providers/ai_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/handwriting_analysis_service.dart';
import '../../../core/services/vision_analysis_gateway.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  static const insecureEndpointMessage = '请求端点必须留空或填写有效的 https:// URL。';
  static const restrictedEndpointMessage =
      '默认仅允许官方 DashScope 端点。如需自定义 HTTPS 代理，请先开启高级模式。';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final config = ref.watch(qwenVisionConfigProvider);
    final includeStudentName = ref.watch(aiIncludeStudentNameProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: 'AI 视觉',
              subtitle: '默认走最保守的远端发送策略，只有显式开启后才放宽边界。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: AsyncValueWidget<Map<String, String>>(
                value: settingsAsync,
                builder: (settings) => ListView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        '当前端点：${_endpointLabel(config.baseUrl)}\n'
                        '模型：${config.model}\n'
                        'API Key：${_maskApiKey(settings[QwenVisionConfig.settingApiKey] ?? '')}\n'
                        '学生姓名外发：${includeStudentName ? '已开启' : '默认关闭'}\n'
                        '自定义端点：${config.allowCustomEndpoint ? '高级模式已开启' : '仅官方 DashScope'}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          _SettingTile(
                            key: const ValueKey('ai_setting_api_key_tile'),
                            icon: Icons.key_outlined,
                            title: 'API Key',
                            subtitle: _maskApiKey(
                              settings[QwenVisionConfig.settingApiKey] ?? '',
                            ),
                            onTap: () => _showEditSheet(
                              context,
                              ref,
                              title: 'Qwen API Key',
                              initialValue:
                                  settings[QwenVisionConfig.settingApiKey] ??
                                  '',
                              hintText: '请输入 DashScope / 百炼侧的 API Key',
                              keyName: QwenVisionConfig.settingApiKey,
                              obscureText: true,
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _SettingSwitchTile(
                            switchKey: const ValueKey(
                              'ai_allow_custom_endpoint_switch',
                            ),
                            icon: Icons.tune_outlined,
                            title: '自定义 HTTPS 端点（高级）',
                            subtitle: config.allowCustomEndpoint
                                ? '已开启，可保存自定义 HTTPS 代理或中转网关。'
                                : '默认关闭，仅允许官方 DashScope 端点。',
                            value: config.allowCustomEndpoint,
                            onChanged: (value) => ref
                                .read(settingsProvider.notifier)
                                .set(
                                  QwenVisionConfig.settingAllowCustomEndpoint,
                                  value.toString(),
                                ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _SettingTile(
                            key: const ValueKey('ai_setting_base_url_tile'),
                            icon: Icons.link_outlined,
                            title: '请求端点',
                            subtitle: config.baseUrl,
                            onTap: () => _showEditSheet(
                              context,
                              ref,
                              title: '请求端点',
                              initialValue:
                                  settings[QwenVisionConfig.settingBaseUrl] ??
                                  config.baseUrl,
                              hintText: QwenVisionConfig.defaultBaseUrl,
                              keyName: QwenVisionConfig.settingBaseUrl,
                              allowCustomEndpoint: config.allowCustomEndpoint,
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _SettingTile(
                            key: const ValueKey('ai_setting_model_tile'),
                            icon: Icons.auto_awesome_outlined,
                            title: '模型标识',
                            subtitle: config.model,
                            onTap: () => _showEditSheet(
                              context,
                              ref,
                              title: '模型标识',
                              initialValue:
                                  settings[QwenVisionConfig.settingModel] ??
                                  config.model,
                              hintText: QwenVisionConfig.defaultModel,
                              keyName: QwenVisionConfig.settingModel,
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _SettingTile(
                            key: const ValueKey(
                              'ai_setting_system_prompt_tile',
                            ),
                            icon: Icons.notes_outlined,
                            title: '系统提示词',
                            subtitle: config.systemPrompt,
                            onTap: () => _showEditSheet(
                              context,
                              ref,
                              title: '系统提示词',
                              initialValue:
                                  settings[QwenVisionConfig
                                      .settingSystemPrompt] ??
                                  config.systemPrompt,
                              hintText: '请输入默认系统提示词',
                              keyName: QwenVisionConfig.settingSystemPrompt,
                              maxLines: 5,
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _SettingSwitchTile(
                            switchKey: const ValueKey(
                              'ai_include_student_name_switch',
                            ),
                            icon: Icons.privacy_tip_outlined,
                            title: '分析时发送学生姓名',
                            subtitle: includeStudentName
                                ? '已开启，学生姓名会作为附加上下文发给远端。'
                                : '默认关闭，仅发送图片和提示词。',
                            value: includeStudentName,
                            onChanged: (value) => ref
                                .read(settingsProvider.notifier)
                                .set(
                                  QwenVisionConfig.settingIncludeStudentName,
                                  value.toString(),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AiWorkbench(modelName: config.model),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initialValue,
    required String hintText,
    required String keyName,
    bool obscureText = false,
    int maxLines = 1,
    bool allowCustomEndpoint = false,
  }) {
    final controller = TextEditingController(text: initialValue);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(sheetCtx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('ai_settings_edit_field'),
                  controller: controller,
                  obscureText: obscureText,
                  maxLines: obscureText ? 1 : maxLines,
                  decoration: InputDecoration(
                    labelText: title,
                    hintText: hintText,
                    helperText: keyName == QwenVisionConfig.settingBaseUrl
                        ? (allowCustomEndpoint
                              ? '当前已允许自定义 HTTPS 地址。'
                              : '如需自定义 HTTPS 地址，请先开启高级模式。')
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const ValueKey('ai_settings_save_button'),
                  onPressed: () async {
                    final value = controller.text.trim();
                    final message = _validateSetting(
                      keyName,
                      value,
                      allowCustomEndpoint: allowCustomEndpoint,
                    );
                    if (message != null) {
                      AppToast.showError(sheetCtx, message);
                      return;
                    }
                    Navigator.of(sheetCtx).pop();
                    await ref
                        .read(settingsProvider.notifier)
                        .set(keyName, value);
                    if (context.mounted) {
                      AppToast.showSuccess(context, '已保存$title');
                    }
                  },
                  child: const Text('保存配置'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _validateSetting(
    String keyName,
    String value, {
    bool allowCustomEndpoint = false,
  }) {
    if (keyName != QwenVisionConfig.settingBaseUrl || value.isEmpty) {
      return null;
    }
    final error = QwenVisionConfig.validateBaseUrl(
      value,
      allowCustomEndpoint: allowCustomEndpoint,
    );
    if (error == QwenVisionConfig.restrictedBaseUrlMessage) {
      return restrictedEndpointMessage;
    }
    if (error != null) {
      return insecureEndpointMessage;
    }
    return null;
  }

  static String _maskApiKey(String value) {
    final text = value.trim();
    if (text.isEmpty) return '未填入';
    if (text.length <= 8) return '已填入';
    return '${text.substring(0, 4)}****${text.substring(text.length - 4)}';
  }

  static String _endpointLabel(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    return uri?.host.isNotEmpty == true ? uri!.host : '未识别';
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final Key switchKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchTile({
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Switch(key: switchKey, value: value, onChanged: onChanged),
    );
  }
}

class _AiWorkbench extends ConsumerStatefulWidget {
  final String modelName;

  const _AiWorkbench({required this.modelName});

  @override
  ConsumerState<_AiWorkbench> createState() => _AiWorkbenchState();
}

class _AiWorkbenchState extends ConsumerState<_AiWorkbench> {
  final _imageSourceController = TextEditingController();
  final _promptController = TextEditingController();
  final _studentController = TextEditingController();
  CalligraphyScriptType _scriptType = CalligraphyScriptType.kaishu;
  HandwritingAnalysisResult? _result;
  String? _errorText;
  bool _submitting = false;

  @override
  void dispose() {
    _imageSourceController.dispose();
    _promptController.dispose();
    _studentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    _imageSourceController.text = image.path;
    setState(() {});
  }

  Future<void> _runAnalysis() async {
    final service = ref.read(handwritingAnalysisServiceProvider);
    final includeStudentName = ref.read(aiIncludeStudentNameProvider);
    if (service == null) {
      AppToast.showError(context, '请先配置 Qwen API Key。');
      return;
    }
    final imageSource = _imageSourceController.text.trim();
    if (imageSource.isEmpty) {
      AppToast.showError(context, '请输入图片 URL 或本地路径。');
      return;
    }
    final localFile = !_isRemote(imageSource);
    final endpointLabel = AiSettingsScreen._endpointLabel(
      ref.read(qwenVisionConfigProvider).baseUrl,
    );
    final outboundDetails = <String>[
      localFile ? '图片内容' : '图片 URL',
      '提示词',
      if (includeStudentName && _studentController.text.trim().isNotEmpty)
        '学生姓名',
    ].join('、');
    final confirmed = await AppToast.showConfirm(
      context,
      localFile
          ? '将向 $endpointLabel 发送$outboundDetails进行分析。本地图片会先转换为 data URL 再上传，请确认你已获得授权并接受外发。'
          : '将向 $endpointLabel 发送$outboundDetails进行分析，请确认你已获得授权并接受外发。',
    );
    if (!confirmed) return;

    setState(() {
      _submitting = true;
      _errorText = null;
      _result = null;
    });
    try {
      final result = await service.analyze(
        HandwritingAnalysisInput(
          imageSource: imageSource,
          scriptType: _scriptType,
          customPrompt: _promptController.text,
          studentName: _studentController.text,
          includeStudentName: includeStudentName,
        ),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on VisionAnalysisException catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(handwritingAnalysisServiceProvider) != null;
    final includeStudentName = ref.watch(aiIncludeStudentNameProvider);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('调试工作台', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('ai_image_source_field'),
            controller: _imageSourceController,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: '图片路径 / URL',
              suffixIcon: IconButton(
                onPressed: _submitting ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('ai_student_name_field'),
            controller: _studentController,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: '学生姓名（可选）',
              helperText: includeStudentName ? '开启后会外发。' : '默认只在本地显示。',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CalligraphyScriptType>(
            key: const ValueKey('ai_script_type_field'),
            initialValue: _scriptType,
            items: CalligraphyScriptType.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(growable: false),
            onChanged: _submitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _scriptType = value);
                    }
                  },
            decoration: const InputDecoration(labelText: '书体'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('ai_prompt_field'),
            controller: _promptController,
            enabled: !_submitting,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '补充提示词（可选）'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const ValueKey('run_qwen_analysis_button'),
              onPressed: enabled && !_submitting ? _runAnalysis : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(_submitting ? '分析中…' : '调用视觉分析'),
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: const TextStyle(color: kSealRed)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('ai_analysis_result_card'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _result!.summary.isNotEmpty
                    ? _result!.summary
                    : _result!.rawText,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isRemote(String source) {
    final uri = Uri.tryParse(source);
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }
}
