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