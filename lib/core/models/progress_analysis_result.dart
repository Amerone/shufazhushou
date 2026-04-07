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

  String get summary => overallAssessment;

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

  factory ProgressAnalysisResult.fromSavedNote({
    required String rawText,
    String model = 'saved-note',
  }) {
    final content = rawText.trim();
    if (content.isEmpty) {
      return const ProgressAnalysisResult(
        isStructured: false,
        model: 'saved-note',
        rawText: '',
        overallAssessment: '',
        trendAnalysis: '',
        strengths: '',
        areasToImprove: '',
        teachingSuggestions: <String>[],
      );
    }

    final overallAssessment = _extractLabeledValue(content, '总体评价');
    final trendAnalysis = _extractLabeledValue(content, '趋势分析');
    final strengths = _extractLabeledValue(content, '优势方面');
    final areasToImprove = _extractLabeledValue(content, '需加强方面');
    final teachingSuggestions = _extractNumberedSection(content, '教学建议');
    final hasStructuredContent =
        overallAssessment.isNotEmpty ||
        trendAnalysis.isNotEmpty ||
        strengths.isNotEmpty ||
        areasToImprove.isNotEmpty ||
        teachingSuggestions.isNotEmpty;

    return ProgressAnalysisResult(
      isStructured: hasStructuredContent,
      model: model,
      rawText: content,
      overallAssessment: overallAssessment.isNotEmpty
          ? overallAssessment
          : AnalysisJsonCodec.firstNonEmptyLine(content),
      trendAnalysis: trendAnalysis,
      strengths: strengths,
      areasToImprove: areasToImprove,
      teachingSuggestions: teachingSuggestions,
    );
  }

  static String _extractLabeledValue(String content, String label) {
    final pattern = RegExp('^$label[：:]\\s*(.*)\$');
    for (final rawLine in content.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      final match = pattern.firstMatch(line);
      if (match != null) {
        return (match.group(1) ?? '').trim();
      }
    }
    return '';
  }

  static List<String> _extractNumberedSection(String content, String label) {
    final lines = content
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .toList(growable: false);
    final items = <String>[];
    var collecting = false;

    for (final line in lines) {
      if (line.isEmpty) {
        continue;
      }

      if (collecting) {
        if (RegExp(r'^[^：:]+[：:]').hasMatch(line) &&
            !RegExp(r'^\d+\.\s+').hasMatch(line)) {
          break;
        }
        items.add(line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim());
        continue;
      }

      if (RegExp('^$label[：:]').hasMatch(line)) {
        collecting = true;
      }
    }

    return items.where((item) => item.isNotEmpty).toList(growable: false);
  }
}
