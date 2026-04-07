import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/data_insight_result.dart';
import 'package:moyun/core/models/progress_analysis_result.dart';

void main() {
  group('ProgressAnalysisResult', () {
    test('parses structured json response', () {
      final result = ProgressAnalysisResult.fromVisionResult(
        model: 'qwen-test',
        rawText: '''
```json
{
  "overall_assessment": "steady",
  "trend_analysis": "upward",
  "strengths": "stroke control",
  "areas_to_improve": "spacing",
  "teaching_suggestions": ["more repetition", "slow practice"]
}
```
''',
      );

      expect(result.isStructured, isTrue);
      expect(result.model, 'qwen-test');
      expect(result.overallAssessment, 'steady');
      expect(result.trendAnalysis, 'upward');
      expect(result.strengths, 'stroke control');
      expect(result.areasToImprove, 'spacing');
      expect(result.teachingSuggestions, ['more repetition', 'slow practice']);
    });

    test('falls back to first line for plain text response', () {
      final result = ProgressAnalysisResult.fromVisionResult(
        model: 'qwen-test',
        rawText: 'Overall summary\nMore details here',
      );

      expect(result.isStructured, isFalse);
      expect(result.overallAssessment, 'Overall summary');
      expect(result.teachingSuggestions, isEmpty);
    });

    test('parses saved note content into progress result', () {
      final result = ProgressAnalysisResult.fromSavedNote(
        rawText:
            '总体评价：最近整体稳定\n'
            '趋势分析：较前几次更顺\n'
            '优势方面：起收笔更干净\n'
            '需加强方面：章法还要再稳一些\n'
            '教学建议：\n'
            '1. 下节课先做控笔热身\n'
            '2. 继续巩固中宫位置',
      );

      expect(result.isStructured, isTrue);
      expect(result.overallAssessment, '最近整体稳定');
      expect(result.trendAnalysis, '较前几次更顺');
      expect(result.strengths, '起收笔更干净');
      expect(result.areasToImprove, '章法还要再稳一些');
      expect(result.teachingSuggestions, ['下节课先做控笔热身', '继续巩固中宫位置']);
    });
  });

  group('DataInsightResult', () {
    test('parses structured json response', () {
      final result = DataInsightResult.fromVisionResult(
        model: 'qwen-test',
        rawText: '''
{
  "summary": "healthy",
  "revenue_insight": "stable",
  "engagement_insight": "active",
  "risk_alerts": ["watch debt"],
  "recommendations": ["follow up parents"]
}
''',
      );

      expect(result.isStructured, isTrue);
      expect(result.summary, 'healthy');
      expect(result.revenueInsight, 'stable');
      expect(result.engagementInsight, 'active');
      expect(result.riskAlerts, ['watch debt']);
      expect(result.recommendations, ['follow up parents']);
    });

    test('falls back to first line for plain text response', () {
      final result = DataInsightResult.fromVisionResult(
        model: 'qwen-test',
        rawText: 'Business summary\nMore details here',
      );

      expect(result.isStructured, isFalse);
      expect(result.summary, 'Business summary');
      expect(result.riskAlerts, isEmpty);
      expect(result.recommendations, isEmpty);
    });
  });
}
