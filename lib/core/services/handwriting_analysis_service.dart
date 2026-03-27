import '../models/handwriting_analysis_result.dart';
import 'vision_analysis_gateway.dart';

enum CalligraphyScriptType {
  kaishu('楷书'),
  xingshu('行书'),
  lishu('隶书'),
  zhuanshu('篆书');

  final String label;

  const CalligraphyScriptType(this.label);
}

class HandwritingAnalysisInput {
  final String imageSource;
  final CalligraphyScriptType scriptType;
  final String? customPrompt;
  final String? studentName;
  final double temperature;

  const HandwritingAnalysisInput({
    required this.imageSource,
    this.scriptType = CalligraphyScriptType.kaishu,
    this.customPrompt,
    this.studentName,
    this.temperature = 0.2,
  });
}

class HandwritingAnalysisService {
  final VisionAnalysisGateway gateway;

  const HandwritingAnalysisService({
    required this.gateway,
  });

  Future<HandwritingAnalysisResult> analyze(
    HandwritingAnalysisInput input,
  ) async {
    final imageSource = input.imageSource.trim();
    if (imageSource.isEmpty) {
      throw const VisionAnalysisException('图片来源不能为空');
    }

    final result = await gateway.analyze(
      VisionAnalysisRequest(
        prompt: buildPrompt(input),
        imageSource: imageSource,
        temperature: input.temperature,
      ),
    );

    return HandwritingAnalysisResult.fromVisionResult(
      model: result.model,
      rawText: result.text,
    );
  }

  static String buildPrompt(HandwritingAnalysisInput input) {
    final sections = <String>[
      '请分析这张书法练习图片。',
      '书体：${input.scriptType.label}。',
    ];

    final studentName = input.studentName?.trim();
    if (studentName != null && studentName.isNotEmpty) {
      sections.add('学生：$studentName。');
    }

    final customPrompt = input.customPrompt?.trim();
    if (customPrompt != null && customPrompt.isNotEmpty) {
      sections.add('补充要求：$customPrompt');
    }

    sections.addAll(const [
      '请只输出一个 JSON 对象，不要输出 markdown 代码块，不要输出额外解释。',
      'JSON 字段结构如下：',
      '{',
      '  "summary": "1-2句总评",',
      '  "stroke_observation": "笔画观察",',
      '  "structure_observation": "结构观察",',
      '  "layout_observation": "章法观察",',
      '  "practice_suggestions": ["建议1", "建议2", "建议3"]',
      '}',
      '要求：',
      '- 所有字段都必须出现。',
      '- 如果某项无法判断，请返回空字符串或空数组，不要编造。',
      '- practice_suggestions 最多 3 条，必须具体可执行。',
      '- 语言简洁，避免空泛表述。',
    ]);

    return sections.join('\n');
  }
}
