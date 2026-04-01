import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/handwriting_analysis_result.dart';
import 'package:moyun/core/services/handwriting_analysis_service.dart';
import 'package:moyun/core/services/vision_analysis_gateway.dart';

void main() {
  group('HandwritingAnalysisService', () {
    test('buildPrompt includes script type and custom context', () {
      final prompt = HandwritingAnalysisService.buildPrompt(
        const HandwritingAnalysisInput(
          imageSource: 'https://example.com/work.jpg',
          scriptType: CalligraphyScriptType.xingshu,
          studentName: '张三',
          customPrompt: '请重点关注笔画连贯性',
        ),
      );

      expect(prompt, contains('书体：行书。'));
      expect(prompt, contains('学生：张三。'));
      expect(prompt, contains('补充要求：请重点关注笔画连贯性'));
      expect(prompt, contains('practice_suggestions'));
      expect(prompt, contains('请只输出一个 JSON 对象'));
    });

    test('buildPrompt omits student name when disabled', () {
      final prompt = HandwritingAnalysisService.buildPrompt(
        const HandwritingAnalysisInput(
          imageSource: 'https://example.com/work.jpg',
          studentName: '张三',
        ),
        includeStudentName: false,
      );

      expect(prompt, isNot(contains('学生：张三。')));
    });

    test('delegates to gateway and returns structured result', () async {
      final gateway = _SpyGateway();
      final service = HandwritingAnalysisService(
        gateway: gateway,
        includeStudentNameByDefault: true,
      );

      final result = await service.analyze(
        const HandwritingAnalysisInput(
          imageSource: '  https://example.com/work.jpg  ',
          scriptType: CalligraphyScriptType.lishu,
          studentName: '李四',
        ),
      );

      expect(gateway.lastRequest, isNotNull);
      expect(gateway.lastRequest!.imageSource, 'https://example.com/work.jpg');
      expect(gateway.lastRequest!.prompt, contains('书体：隶书。'));
      expect(gateway.lastRequest!.prompt, contains('学生：李四。'));
      expect(result.model, 'qwen3-vl-plus');
      expect(result.isStructured, isTrue);
      expect(result.summary, '整体结构稳定，行笔较自然。');
      expect(result.strokeObservation, '起收笔较明确，但转折处略显生硬。');
      expect(result.practiceSuggestions, hasLength(2));
    });

    test('service omits student name by default', () async {
      final gateway = _SpyGateway();
      final service = HandwritingAnalysisService(gateway: gateway);

      await service.analyze(
        const HandwritingAnalysisInput(
          imageSource: 'https://example.com/work.jpg',
          studentName: '王五',
        ),
      );

      expect(gateway.lastRequest, isNotNull);
      expect(gateway.lastRequest!.prompt, isNot(contains('学生：王五。')));
    });

    test('falls back to raw text summary when response is not json', () {
      final result = HandwritingAnalysisResult.fromVisionResult(
        model: 'qwen3-vl-plus',
        rawText: '整体完成度不错。\n建议继续强化横画起笔。',
      );

      expect(result.summary, '整体完成度不错。');
      expect(result.isStructured, isFalse);
      expect(result.practiceSuggestions, isEmpty);
    });

    test('parses fenced json payload', () {
      final result = HandwritingAnalysisResult.fromVisionResult(
        model: 'qwen3-vl-plus',
        rawText: '''
```json
{
  "summary": "结构解析成功",
  "stroke_observation": "笔画较稳",
  "structure_observation": "结构较匀称",
  "layout_observation": "",
  "practice_suggestions": ["继续慢练"]
}
```
''',
      );

      expect(result.summary, '结构解析成功');
      expect(result.isStructured, isTrue);
      expect(result.strokeObservation, '笔画较稳');
      expect(result.practiceSuggestions, ['继续慢练']);
    });

    test('supports camelCase keys and string suggestions', () {
      final result = HandwritingAnalysisResult.fromVisionResult(
        model: 'qwen3-vl-plus',
        rawText: '''
{
  "summary": "支持 camelCase",
  "strokeObservation": "笔画顺畅",
  "structureObservation": "结构稳定",
  "layoutObservation": "章法自然",
  "practiceSuggestions": "1. 继续慢写\\n2. 留意转折"
}
''',
      );

      expect(result.isStructured, isTrue);
      expect(result.strokeObservation, '笔画顺畅');
      expect(result.practiceSuggestions, ['继续慢写', '留意转折']);
    });
  });
}

class _SpyGateway implements VisionAnalysisGateway {
  VisionAnalysisRequest? lastRequest;

  @override
  Future<VisionAnalysisResult> analyze(VisionAnalysisRequest request) async {
    lastRequest = request;
    return const VisionAnalysisResult(
      model: 'qwen3-vl-plus',
      text: '''
{
  "summary": "整体结构稳定，行笔较自然。",
  "stroke_observation": "起收笔较明确，但转折处略显生硬。",
  "structure_observation": "中宫较稳，左右部件关系处理基本准确。",
  "layout_observation": "字距比较均匀，但行气还可以更连贯。",
  "practice_suggestions": ["继续做横画起笔慢练", "每次练习后复盘字距控制"]
}
''',
      raw: <String, dynamic>{},
    );
  }

  @override
  Future<VisionAnalysisResult> analyzeText(TextAnalysisRequest request) async {
    throw const VisionAnalysisException(
      'Text analysis is not used in this test.',
    );
  }
}
