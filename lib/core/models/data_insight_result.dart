import '../services/analysis_result_codec.dart';

class DataInsightResult {
  final bool isStructured;
  final String model;
  final String rawText;
  final String summary;
  final String revenueInsight;
  final String engagementInsight;
  final List<String> riskAlerts;
  final List<String> recommendations;

  const DataInsightResult({
    required this.isStructured,
    required this.model,
    required this.rawText,
    required this.summary,
    required this.revenueInsight,
    required this.engagementInsight,
    required this.riskAlerts,
    required this.recommendations,
  });

  factory DataInsightResult.fromVisionResult({
    required String model,
    required String rawText,
  }) {
    final parsed = AnalysisJsonCodec.tryParseObject(rawText);
    if (parsed != null) {
      return DataInsightResult.fromMap(
        model: model,
        rawText: rawText,
        map: parsed,
      );
    }

    return DataInsightResult(
      isStructured: false,
      model: model,
      rawText: rawText.trim(),
      summary: AnalysisJsonCodec.firstNonEmptyLine(rawText),
      revenueInsight: '',
      engagementInsight: '',
      riskAlerts: const <String>[],
      recommendations: const <String>[],
    );
  }

  factory DataInsightResult.fromMap({
    required String model,
    required String rawText,
    required Map<String, dynamic> map,
  }) {
    return DataInsightResult(
      isStructured: true,
      model: model,
      rawText: rawText.trim(),
      summary: AnalysisJsonCodec.readString(map, 'summary'),
      revenueInsight: AnalysisJsonCodec.readString(
        map,
        'revenue_insight',
        alternateKey: 'revenueInsight',
      ),
      engagementInsight: AnalysisJsonCodec.readString(
        map,
        'engagement_insight',
        alternateKey: 'engagementInsight',
      ),
      riskAlerts: AnalysisJsonCodec.readStringList(
        map['risk_alerts'] ?? map['riskAlerts'],
        maxItems: 5,
      ),
      recommendations: AnalysisJsonCodec.readStringList(map['recommendations']),
    );
  }
}
