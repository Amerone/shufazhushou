import 'dart:convert';

class AnalysisJsonCodec {
  const AnalysisJsonCodec._();

  static Map<String, dynamic>? tryParseObject(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;

    final candidate = _extractJsonObject(normalized);
    if (candidate == null) return null;

    try {
      final decoded = jsonDecode(candidate);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String readString(
    Map<String, dynamic> map,
    String key, {
    String? alternateKey,
  }) {
    final direct = map[key];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    if (alternateKey == null) return '';
    final alternate = map[alternateKey];
    if (alternate is String && alternate.trim().isNotEmpty) {
      return alternate.trim();
    }
    return '';
  }

  static List<String> readStringList(dynamic value, {int maxItems = 3}) {
    if (value is String) {
      return value
          .split(RegExp(r'[\r\n]+'))
          .map((item) => item.trim())
          .map(
            (item) => item.replaceFirst(RegExp(r'^(?:[-*?]|\d+[.)、])\s*'), ''),
          )
          .where((item) => item.isNotEmpty)
          .take(maxItems)
          .toList(growable: false);
    }

    if (value is! List) return const <String>[];

    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(maxItems)
        .toList(growable: false);
  }

  static String firstNonEmptyLine(String rawText) {
    final normalized = rawText.trim();
    if (normalized.isEmpty) return '';

    for (final line in normalized.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  static String? _extractJsonObject(String text) {
    final fenced = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fenced != null) {
      final content = fenced.group(1)?.trim();
      if (content != null && content.startsWith('{') && content.endsWith('}')) {
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

      if (char == r'\') {
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
