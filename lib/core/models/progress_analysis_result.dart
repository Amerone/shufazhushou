import '../services/analysis_result_codec.dart';

class ProgressAnalysisResult {
  final bool isStructured;
  final String model;
  final String rawText;
  final String overallAssessment;
  final String trendAnalysis;
  final String strengths;
  final String areasToImprove;
  final List<String> teachingSuggestions;

  const ProgressAnalysisResult({
    required this.isStructured,
    required this.model,
    required this.rawText,
    required this.overallAssessment,
    required this.trendAnalysis,
    required this.strengths,
    required this.areasToImprove,
    required this.teachingSuggestions,
  });

  factory ProgressAnalysisResult.fromVisionResult({
    required String model,
    required String rawText,
  }) {
    final parsed = AnalysisJsonCodec.tryParseObject(rawText);
    if (parsed != null) {
      return ProgressAnalysisResult.fromMap(
        model: model,
        rawText: rawText,
        map: parsed,
      );
    }

    return ProgressAnalysisResult(
      isStructured: false,
      model: model,
      rawText: rawText.trim(),
      overallAssessment: AnalysisJsonCodec.firstNonEmptyLine(rawText),
      trendAnalysis: '',
      strengths: '',
      areasToImprove: '',
      teachingSuggestions: const <String>[],
    );
  }

  factory ProgressAnalysisResult.fromMap({
    required String model,
    required String rawText,
    required Map<String, dynamic> map,
  }) {
    return ProgressAnalysisResult(
      isStructured: true,
      model: model,
      rawText: rawText.trim(),
      overallAssessment: AnalysisJsonCodec.readString(
        map,
        'overall_assessment',
        alternateKey: 'overallAssessment',
      ),
      trendAnalysis: AnalysisJsonCodec.readString(
        map,
        'trend_analysis',
        alternateKey: 'trendAnalysis',
      ),
      strengths: AnalysisJsonCodec.readString(map, 'strengths'),
      areasToImprove: AnalysisJsonCodec.readString(
        map,
        'areas_to_improve',
        alternateKey: 'areasToImprove',
      ),
      teachingSuggestions: AnalysisJsonCodec.readStringList(
        map['teaching_suggestions'] ?? map['teachingSuggestions'],
      ),
    );
  }
}
