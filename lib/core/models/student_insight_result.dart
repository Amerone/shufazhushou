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

  factory StudentInsightResult.fromSavedNote({
    required String rawText,
    String model = 'saved-note',
  }) {
    final content = rawText.trim();
    if (content.isEmpty) {
      return StudentInsightResult(
        isStructured: false,
        model: model,
        rawText: '',
        summary: '',
        attendancePattern: '',
        writingObservation: '',
        progressInsight: '',
        riskAlerts: <String>[],
        teachingSuggestions: <String>[],
        parentCommunicationTip: '',
      );
    }

    final summary = _extractLabeledValue(content, '总体画像');
    final attendancePattern = _extractLabeledValue(content, '上课规律');
    final writingObservation = _extractLabeledValue(content, '作品观察');
    final progressInsight = _extractLabeledValue(content, '进步判断');
    final riskAlerts = _extractNumberedSection(content, '风险提醒');
    final teachingSuggestions = _extractNumberedSection(content, '教学建议');
    final parentCommunicationTip = _extractLabeledValue(content, '家长沟通');
    final hasStructuredContent =
        summary.isNotEmpty ||
        attendancePattern.isNotEmpty ||
        writingObservation.isNotEmpty ||
        progressInsight.isNotEmpty ||
        riskAlerts.isNotEmpty ||
        teachingSuggestions.isNotEmpty ||
        parentCommunicationTip.isNotEmpty;

    return StudentInsightResult(
      isStructured: hasStructuredContent,
      model: model,
      rawText: content,
      summary: summary.isNotEmpty
          ? summary
          : AnalysisJsonCodec.firstNonEmptyLine(content),
      attendancePattern: attendancePattern,
      writingObservation: writingObservation,
      progressInsight: progressInsight,
      riskAlerts: riskAlerts,
      teachingSuggestions: teachingSuggestions,
      parentCommunicationTip: parentCommunicationTip,
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
