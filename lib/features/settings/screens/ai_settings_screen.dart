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
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final config = ref.watch(qwenVisionConfigProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: 'AI 视觉',
              subtitle: '预留 Qwen 视觉模型接入配置，当前按 Qwen3-VL-Plus 方向准备。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (settings) {
                  final configured = config.isConfigured;
                  final endpointLabel = _endpointLabel(config.baseUrl);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: (configured ? kGreen : kOrange).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.psychology_alt_outlined,
                                    color: configured ? kGreen : kOrange,
                                  ),
                                ),
                                SizedBox(
                                  width: 240,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Qwen 调用入口',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        configured
                                            ? '配置已保存，后续可以直接从 provider 侧调用视觉分析网关。'
                                            : '当前尚未配置 API Key，入口已准备好但不会发起远端请求。',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (configured ? kGreen : kOrange).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    configured ? '已配置' : '待配置',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: configured ? kGreen : kOrange,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 720 ? 3 : 2;
                                final itemWidth =
                                    (constraints.maxWidth - 12 * (columns - 1)) / columns;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: itemWidth,
                                      child: _AiMetric(
                                        icon: Icons.key_outlined,
                                        label: 'API Key',
                                        value: configured ? '已填写' : '未填写',
                                        color: configured ? kGreen : kOrange,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _AiMetric(
                                        icon: Icons.model_training_outlined,
                                        label: '当前模型',
                                        value: config.model,
                                        color: kPrimaryBlue,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _AiMetric(
                                        icon: Icons.hub_outlined,
                                        label: '网关',
                                        value: endpointLabel,
                                        color: kSealRed,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'API Key 仅保存在当前设备，不写入应用数据库备份；发起分析时会把图片、提示词和学员名发送到配置的远端服务。',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: kInkSecondary,
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(
                        title: '配置项',
                        subtitle: '这里仅保存调用配置，不会主动上传图片或请求远端服务。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _AiTile(
                              icon: Icons.key_outlined,
                              title: 'API Key',
                              subtitle: _maskApiKey(settings[QwenVisionConfig.settingApiKey] ?? ''),
                              onTap: () => _showEditSheet(
                                context,
                                ref,
                                title: 'Qwen API Key',
                                hintText: '请输入 DashScope / 百炼侧的 API Key',
                                initialValue: settings[QwenVisionConfig.settingApiKey] ?? '',
                                keyName: QwenVisionConfig.settingApiKey,
                                obscureText: true,
                              ),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _AiTile(
                              icon: Icons.link_outlined,
                              title: '请求端点',
                              subtitle: config.baseUrl,
                              onTap: () => _showEditSheet(
                                context,
                                ref,
                                title: '请求端点',
                                hintText: QwenVisionConfig.defaultBaseUrl,
                                initialValue: settings[QwenVisionConfig.settingBaseUrl] ?? config.baseUrl,
                                keyName: QwenVisionConfig.settingBaseUrl,
                              ),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _AiTile(
                              icon: Icons.auto_awesome_outlined,
                              title: '模型标识',
                              subtitle: config.model,
                              onTap: () => _showEditSheet(
                                context,
                                ref,
                                title: '模型标识',
                                hintText: QwenVisionConfig.defaultModel,
                                initialValue: settings[QwenVisionConfig.settingModel] ?? config.model,
                                keyName: QwenVisionConfig.settingModel,
                              ),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _AiTile(
                              icon: Icons.notes_outlined,
                              title: '系统提示词',
                              subtitle: config.systemPrompt,
                              onTap: () => _showEditSheet(
                                context,
                                ref,
                                title: '系统提示词',
                                hintText: '请输入默认系统提示词',
                                initialValue: settings[QwenVisionConfig.settingSystemPrompt] ?? config.systemPrompt,
                                keyName: QwenVisionConfig.settingSystemPrompt,
                                maxLines: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(
                        title: '代码入口',
                        subtitle: '后续业务调用时，优先走统一 provider，不直接在 UI 里拼远端请求。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Provider: `handwritingAnalysisServiceProvider`',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Config: `QwenVisionConfig.fromSettings(...)`\nService: `HandwritingAnalysisService.analyze(...) -> HandwritingAnalysisResult`\nGateway: `QwenVisionGateway.analyze(...)`\n请求体按兼容 Chat Completions 形式构造，图片支持远程 URL 和本地文件转 data URL。',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: kInkSecondary,
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AiWorkbench(modelName: config.model),
                    ],
                  );
                },
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
    required String hintText,
    required String initialValue,
    required String keyName,
    bool obscureText = false,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom +
                  MediaQuery.of(sheetCtx).padding.bottom +
                  16,
            ),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(sheetCtx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    obscureText: obscureText,
                    maxLines: obscureText ? 1 : maxLines,
                    decoration: InputDecoration(
                      labelText: title,
                      hintText: hintText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.56),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final value = controller.text.trim();
                      Navigator.of(sheetCtx).pop();
                      await ref.read(settingsProvider.notifier).set(
                            keyName,
                            value,
                          );
                      if (context.mounted) AppToast.showSuccess(context, '已保存$title');
                    },
                    child: const Text('保存配置'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _maskApiKey(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '未填写';
    if (trimmed.length <= 8) return '已填写';
    return '${trimmed.substring(0, 4)}****${trimmed.substring(trimmed.length - 4)}';
  }

  static String _endpointLabel(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return '未识别';
    return uri.host;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kInkSecondary,
              ),
        ),
      ],
    );
  }
}

class _AiMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AiMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AiTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AiTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: kPrimaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: kPrimaryBlue, size: 20),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle.isEmpty ? '未设置' : subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.edit_outlined, size: 20),
      onTap: onTap,
    );
  }
}

class _AiWorkbench extends ConsumerStatefulWidget {
  final String modelName;

  const _AiWorkbench({
    required this.modelName,
  });

  @override
  ConsumerState<_AiWorkbench> createState() => _AiWorkbenchState();
}

class _AiWorkbenchState extends ConsumerState<_AiWorkbench> {
  late final TextEditingController _imageSourceController;
  late final TextEditingController _promptController;
  late final TextEditingController _studentController;

  CalligraphyScriptType _scriptType = CalligraphyScriptType.kaishu;
  bool _submitting = false;
  HandwritingAnalysisResult? _result;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _imageSourceController = TextEditingController();
    _promptController = TextEditingController(
      text: '请结合课堂反馈视角，指出当前这张作业最值得继续强化的练习点。',
    );
    _studentController = TextEditingController();
  }

  @override
  void dispose() {
    _imageSourceController.dispose();
    _promptController.dispose();
    _studentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    _imageSourceController.text = image.path;
    setState(() {});
  }

  Future<void> _runAnalysis() async {
    final service = ref.read(handwritingAnalysisServiceProvider);
    if (service == null) {
      AppToast.showError(context, '请先配置 Qwen API Key');
      return;
    }

    final imageSource = _imageSourceController.text.trim();
    if (imageSource.isEmpty) {
      AppToast.showError(context, '请输入图片 URL 或本地路径');
      return;
    }

    final config = ref.read(qwenVisionConfigProvider);
    final endpointLabel = AiSettingsScreen._endpointLabel(config.baseUrl);
    final localFile = _isLocalImageSource(imageSource);
    final confirmed = await AppToast.showConfirm(
      context,
      localFile
          ? '将向 $endpointLabel 发送图片、提示词和学员名进行分析。本地图片会先转换为 data URL 再上传，请确认你已获得授权并接受外发。'
          : '将向 $endpointLabel 发送图片 URL、提示词和学员名进行分析，请确认你已获得授权并接受外发。',
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
        ),
      );

      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } on VisionAnalysisException catch (error) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _errorText = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(handwritingAnalysisServiceProvider);
    final enabled = service != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: '调试调用',
          subtitle: '这里提供一个最小可用入口，便于直接验证 Qwen3-VL-Plus 侧的图片分析调用。',
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前模型：${widget.modelName}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '从相册选取书法作业图片，或输入公网图片 URL 进行分析。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kInkSecondary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('ai_image_source_field'),
                      controller: _imageSourceController,
                      enabled: !_submitting,
                      decoration: InputDecoration(
                        labelText: '图片路径 / URL',
                        hintText: '点击右侧按钮从相册选取',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _submitting ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: kPrimaryBlue.withValues(alpha: 0.12),
                      foregroundColor: kPrimaryBlue,
                      fixedSize: const Size(52, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ai_student_name_field'),
                controller: _studentController,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: '学生名（可选）',
                  hintText: '用于补充分析上下文',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.56),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CalligraphyScriptType>(
                key: const ValueKey('ai_script_type_field'),
                value: _scriptType,
                decoration: InputDecoration(
                  labelText: '书体',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.56),
                ),
                items: CalligraphyScriptType.values
                    .map(
                      (type) => DropdownMenuItem<CalligraphyScriptType>(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: !_submitting
                    ? (value) {
                        if (value == null) return;
                        setState(() => _scriptType = value);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ai_prompt_field'),
                controller: _promptController,
                enabled: !_submitting,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: '补充提示词（可选）',
                  hintText: '用于覆盖默认分析重点',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.56),
                ),
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
                  label: Text(_submitting ? '分析中...' : '调用视觉分析'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                enabled
                    ? '请求会走 `handwritingAnalysisServiceProvider` -> `visionAnalysisGatewayProvider`。'
                    : '未配置 API Key 时只保留入口，不会发起远端调用。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: enabled ? kInkSecondary : kOrange,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '运行前会再次确认远端上传；API Key 不随应用备份导出。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kOrange,
                      height: 1.5,
                    ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kSealRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _errorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: kSealRed,
                          height: 1.5,
                        ),
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                Container(
                  key: const ValueKey('ai_analysis_result_card'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kPrimaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _result!.hasStructuredContent
                            ? '结构化结果 · ${_result!.model}'
                            : '分析结果 · ${_result!.model}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: kPrimaryBlue,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _AnalysisSection(label: '总评', content: _result!.summary),
                      if (_result!.strokeObservation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _AnalysisSection(
                          label: '笔画观察',
                          content: _result!.strokeObservation,
                        ),
                      ],
                      if (_result!.structureObservation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _AnalysisSection(
                          label: '结构观察',
                          content: _result!.structureObservation,
                        ),
                      ],
                      if (_result!.layoutObservation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _AnalysisSection(
                          label: '章法观察',
                          content: _result!.layoutObservation,
                        ),
                      ],
                      if (_result!.practiceSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '练习建议',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: kPrimaryBlue,
                              ),
                        ),
                        const SizedBox(height: 6),
                        for (var i = 0; i < _result!.practiceSuggestions.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == _result!.practiceSuggestions.length - 1 ? 0 : 6,
                            ),
                            child: Text(
                              '${i + 1}. ${_result!.practiceSuggestions[i]}',
                              key: ValueKey('ai_analysis_suggestion_$i'),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.6,
                                  ),
                            ),
                          ),
                      ],
                      if (_result!.rawText.isNotEmpty &&
                          _result!.rawText.trim() != _result!.summary.trim()) ...[
                        const SizedBox(height: 12),
                        Text(
                          '原始返回',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: kInkSecondary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _result!.rawText,
                          key: const ValueKey('ai_analysis_result_text'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                height: 1.6,
                                color: kInkSecondary,
                              ),
                        ),
                      ] else
                        SelectableText(
                          _result!.summary,
                          key: const ValueKey('ai_analysis_result_text'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.6,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _isLocalImageSource(String imageSource) {
    final trimmed = imageSource.trim().toLowerCase();
    return !(trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:'));
  }
}

class _AnalysisSection extends StatelessWidget {
  final String label;
  final String content;

  const _AnalysisSection({
    required this.label,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: kPrimaryBlue,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          content.isEmpty ? '未返回' : content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
        ),
      ],
    );
  }
}
