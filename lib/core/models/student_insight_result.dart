import '../services/analysis_result_codec.dart';

class StudentInsightResult {
  final bool isStructured;
  final String model;
  final String rawText;
  final String summary;
  final String attendancePattern;
  final String writingObservation;
  final String progressInsight;
  final List<String> riskAlerts;
  final List<String> teachingSuggestions;
  final String parentCommunicationTip;

  const StudentInsightResult({
    required this.isStructured,
    required this.model,
    required this.rawText,
    required this.summary,
    required this.attendancePattern,
    required this.writingObservation,
    required this.progressInsight,
    required this.riskAlerts,
    required this.teachingSuggestions,
    required this.parentCommunicationTip,
  });

  factory StudentInsightResult.fromVisionResult({
    required String model,
    required String rawText,
  }) {
    final parsed = AnalysisJsonCodec.tryParseObject(rawText);
    if (parsed != null) {
      return StudentInsightResult.fromMap(
        model: model,
        rawText: rawText,
        map: parsed,
      );
    }

    return StudentInsightResult(
      isStructured: false,
      model: model,
      rawText: rawText.trim(),
      summary: AnalysisJsonCodec.firstNonEmptyLine(rawText),
      attendancePattern: '',
      writingObservation: '',
      progressInsight: '',
      riskAlerts: const <String>[],
      teachingSuggestions: const <String>[],
      parentCommunicationTip: '',
    );
  }

  factory StudentInsightResult.fromMap({
    required String model,
    required String rawText,
    required Map<String, dynamic> map,
  }) {
    return StudentInsightResult(
      isStructured: true,
      model: model,
      rawText: rawText.trim(),
      summary: AnalysisJsonCodec.readString(map, 'summary'),
      attendancePattern: AnalysisJsonCodec.readString(
        map,
        'attendance_pattern',
        alternateKey: 'attendancePattern',
      ),
      writingObservation: AnalysisJsonCodec.readString(
        map,
        'writing_observation',
        alternateKey: 'writingObservation',
      ),
      progressInsight: AnalysisJsonCodec.readString(
        map,
        'progress_insight',
        alternateKey: 'progressInsight',
      ),
      riskAlerts: AnalysisJsonCodec.readStringList(
        map['risk_alerts'] ?? map['riskAlerts'],
        maxItems: 4,
      ),
      teachingSuggestions: AnalysisJsonCodec.readStringList(
        map['teaching_suggestions'] ?? map['teachingSuggestions'],
      ),
      parentCommunicationTip: AnalysisJsonCodec.readString(
        map,
        'parent_communication_tip',
        alternateKey: 'parentCommunicationTip',
      ),
    );
  }
}
