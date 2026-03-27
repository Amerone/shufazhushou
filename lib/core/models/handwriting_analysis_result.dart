import 'dart:convert';

class HandwritingAnalysisResult {
  final bool isStructured;
  final String model;
  final String rawText;
  final String summary;
  final String strokeObservation;
  final String structureObservation;
  final String layoutObservation;
  final List<String> practiceSuggestions;

  const HandwritingAnalysisResult({
    required this.isStructured,
    required this.model,
    required this.rawText,
    required this.summary,
    required this.strokeObservation,
    required this.structureObservation,
    required this.layoutObservation,
    required this.practiceSuggestions,
  });

  bool get hasStructuredContent {
    return isStructured;
  }

  factory HandwritingAnalysisResult.fromVisionResult({
    required String model,
    required String rawText,
  }) {
    final parsed = HandwritingAnalysisJsonCodec.tryParse(rawText);
    if (parsed != null) {
      return HandwritingAnalysisResult.fromMap(
        model: model,
        rawText: rawText,
        map: parsed,
      );
    }

    return HandwritingAnalysisResult(
      isStructured: false,
      model: model,
      rawText: rawText.trim(),
      summary: _fallbackSummary(rawText),
      strokeObservation: '',
      structureObservation: '',
      layoutObservation: '',
      practiceSuggestions: const <String>[],
    );
  }

  factory HandwritingAnalysisResult.fromMap({
    required String model,
    required String rawText,
    required Map<String, dynamic> map,
  }) {
    return HandwritingAnalysisResult(
      isStructured: true,
      model: model,
      rawText: rawText.trim(),
      summary: _readString(map, 'summary'),
      strokeObservation:
          _readString(map, 'stroke_observation', alternateKey: 'strokeObservation'),
      structureObservation: _readString(
        map,
        'structure_observation',
        alternateKey: 'structureObservation',
      ),
      layoutObservation:
          _readString(map, 'layout_observation', alternateKey: 'layoutObservation'),
      practiceSuggestions: _readSuggestions(
        map['practice_suggestions'] ?? map['practiceSuggestions'],
      ),
    );
  }

  static String _readString(
    Map<String, dynamic> map,
    String key, {
    String? alternateKey,
  }) {
    final direct = map[key];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();

    if (alternateKey == null) return '';
    final alternate = map[alternateKey];
    if (alternate is String && alternate.trim().isNotEmpty) {
      return alternate.trim();
    }
    return '';
  }

  static List<String> _readSuggestions(dynamic value) {
    if (value is String) {
      return value
          .split(RegExp(r'[\r\n]+'))
          .map((item) => item.trim())
          .map(
            (item) => item.replaceFirst(
              RegExp(r'^(?:[-*•]|\d+[.)、])\s*'),
              '',
            ),
          )
          .where((item) => item.isNotEmpty)
          .take(3)
          .toList(growable: false);
    }

    if (value is! List) return const <String>[];

    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList(growable: false);
  }

  static String _fallbackSummary(String rawText) {
    final normalized = rawText.trim();
    if (normalized.isEmpty) return '';

    final lines = normalized
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return normalized;
    return lines.first;
  }
}

class HandwritingAnalysisJsonCodec {
  const HandwritingAnalysisJsonCodec._();

  static Map<String, dynamic>? tryParse(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;

    final candidate = _extractJsonObject(normalized);
    if (candidate == null) return null;

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  static String? _extractJsonObject(String text) {
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
        .firstMatch(text);
    if (fenced != null) {
      final content = fenced.group(1)?.trim();
      if (content != null &&
          content.startsWith('{') &&
          content.endsWith('}')) {
        return content;
      }
    }

    return _extractBalancedJsonObject(text);
  }

  static String? _extractBalancedJsonObject(String text) {
    final start = text.indexOf('{');
    if (start == -1) return null;

    var depth = 0;
    var inString = false;
    var isEscaped = false;

    for (var i = start; i < text.length; i++) {
      final char = text[i];

      if (isEscaped) {
        isEscaped = false;
        continue;
      }

      if (char == '\\') {
        isEscaped = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        continue;
      }

      if (inString) continue;

      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return text.substring(start, i + 1);
        }
      }
    }

    return null;
  }
}
