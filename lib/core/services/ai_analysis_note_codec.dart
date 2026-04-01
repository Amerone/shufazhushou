import '../models/ai_analysis_note_entry.dart';

class AiAnalysisNoteCodec {
  const AiAnalysisNoteCodec._();

  static const _startTag = '[AI_ANALYSIS_START';
  static const _endTag = '[AI_ANALYSIS_END]';
  static final _displayTitlePattern = RegExp('^\u3010AI .+\u3011\$');
  static final _legacyDisplayTitlePattern = RegExp(
    '^\uFFFD\uFFFDAI .+\uFFFD\uFFFD\$',
  );
  static final _legacyProgressTitlePatterns = <RegExp>[
    RegExp('^AI \\u5b66\\u4e60\\u5206\\u6790\$'),
    RegExp('^AI Progress Analysis\$'),
  ];
  static final _legacyProgressMarkerPatterns = <RegExp>[
    RegExp('^\\u603b\\u4f53\\u8bc4\\u4ef7[\\uFF1A:]'),
    RegExp('^\\u8d8b\\u52bf\\u5206\\u6790[\\uFF1A:]'),
    RegExp('^\\u4f18\\u52bf\\u65b9\\u9762[\\uFF1A:]'),
    RegExp('^\\u9700\\u52a0\\u5f3a\\u65b9\\u9762[\\uFF1A:]'),
    RegExp('^\\u6559\\u5b66\\u5efa\\u8bae[\\uFF1A:]?'),
    RegExp('^Overall:'),
    RegExp('^Trend:'),
    RegExp('^Strengths:'),
    RegExp('^Needs work:'),
    RegExp('^Teaching suggestions:?'),
  ];

  static String appendEntry(
    String? existingNote, {
    required String type,
    required String analysisText,
    DateTime? createdAt,
    String? title,
  }) {
    final content = analysisText.trim();
    if (content.isEmpty) {
      return (existingNote ?? '').trim();
    }

    final entry = AiAnalysisNoteEntry(
      type: type.trim().isEmpty ? 'general' : type.trim(),
      createdAt: createdAt ?? DateTime.now(),
      content: content,
    );

    final encoded = encodeEntry(
      entry,
      title: title ?? _titleForType(entry.type),
    );
    final base = (existingNote ?? '').trim();
    if (base.isEmpty) return encoded;
    return '$base\n\n$encoded';
  }

  static String appendProgressAnalysis({
    String? existingNote,
    required String analysisText,
    DateTime? analyzedAt,
  }) {
    return appendEntry(
      existingNote,
      type: 'progress',
      analysisText: analysisText,
      createdAt: analyzedAt,
      title: 'AI \u5b66\u4e60\u5206\u6790',
    );
  }

  static String appendHandwritingAnalysis({
    String? existingNote,
    required String analysisText,
    DateTime? analyzedAt,
  }) {
    return appendEntry(
      existingNote,
      type: 'handwriting',
      analysisText: analysisText,
      createdAt: analyzedAt,
      title: 'AI 课堂作品分析',
    );
  }

  static String appendStudentInsight({
    String? existingNote,
    required String analysisText,
    DateTime? analyzedAt,
  }) {
    return appendEntry(
      existingNote,
      type: 'student_insight',
      analysisText: analysisText,
      createdAt: analyzedAt,
      title: 'AI 学生洞察',
    );
  }

  static String encodeEntry(AiAnalysisNoteEntry entry, {String? title}) {
    final timestamp = entry.createdAt.toIso8601String();
    final displayTime = _formatDisplayTime(entry.createdAt);
    final displayTitle = title ?? _titleForType(entry.type);
    return '$_startTag|${entry.type}|$timestamp]\n'
        '\u3010$displayTitle $displayTime\u3011\n'
        '${entry.content.trim()}\n'
        '$_endTag';
  }

  static List<AiAnalysisNoteEntry> decodeEntries(String? note) {
    final text = (note ?? '').trim();
    if (text.isEmpty) return const <AiAnalysisNoteEntry>[];

    final pattern = RegExp(
      r'\[AI_ANALYSIS_START\|([^|\]]+)\|([^\]]+)\]\r?\n([\s\S]*?)\r?\n\[AI_ANALYSIS_END\]',
      multiLine: true,
    );

    final entries = <AiAnalysisNoteEntry>[];
    for (final match in pattern.allMatches(text)) {
      final type = (match.group(1) ?? '').trim();
      final createdAt = DateTime.tryParse((match.group(2) ?? '').trim());
      final content = _stripDisplayTitle((match.group(3) ?? '').trim());
      if (type.isEmpty || createdAt == null || content.isEmpty) {
        continue;
      }

      entries.add(
        AiAnalysisNoteEntry(type: type, createdAt: createdAt, content: content),
      );
    }

    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  static AiAnalysisNoteEntry? latestEntry(String? note, {String? type}) {
    final entries = decodeEntries(note);
    if (entries.isEmpty) return null;
    if (type == null || type.trim().isEmpty) {
      return entries.last;
    }

    final targetType = type.trim();
    for (final entry in entries.reversed) {
      if (entry.type == targetType) {
        return entry;
      }
    }
    return null;
  }

  static String? latestContent(String? note, {String? type}) {
    final entry = latestEntry(note, type: type);
    if (entry == null) return null;
    final content = entry.content.trim();
    return content.isEmpty ? null : content;
  }

  static String? latestProgressContentForExport(String? note) {
    final structured = latestContent(note, type: 'progress');
    if (structured != null) {
      return structured;
    }
    return _extractLegacyProgressContent(note);
  }

  static bool hasStructuredEntry(String? note) {
    final text = (note ?? '').trim();
    if (text.isEmpty) return false;
    return text.contains(_startTag) && text.contains(_endTag);
  }

  static String _stripDisplayTitle(String content) {
    final lines = content.trim().split(RegExp(r'[\r\n]+'));
    if (lines.isEmpty) return '';
    final firstLine = lines.first.trim();
    if (!_displayTitlePattern.hasMatch(firstLine) &&
        !_legacyDisplayTitlePattern.hasMatch(firstLine)) {
      return content.trim();
    }
    return lines.skip(1).join('\n').trim();
  }

  static String? _extractLegacyProgressContent(String? note) {
    final text = (note ?? '').trim();
    if (text.isEmpty) return null;

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n+'));
    for (final block in blocks.reversed) {
      final content = _extractLegacyProgressBlock(block);
      if (content != null) {
        return content;
      }
    }
    return _extractLegacyProgressBlock(normalized);
  }

  static String? _extractLegacyProgressBlock(String block) {
    final lines = block
        .split('\n')
        .map((line) => line.trimRight())
        .toList(growable: false);
    if (lines.isEmpty) return null;

    var startIndex = -1;
    var sawMarker = false;

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;

      if (startIndex == -1 &&
          (_isLegacyProgressTitle(trimmed) ||
              _displayTitlePattern.hasMatch(trimmed) ||
              _legacyDisplayTitlePattern.hasMatch(trimmed))) {
        startIndex = i;
        continue;
      }

      if (_isLegacyProgressMarker(trimmed)) {
        sawMarker = true;
        startIndex = startIndex == -1 ? i : startIndex;
      }
    }

    if (!sawMarker || startIndex == -1) {
      return null;
    }

    final selectedLines = lines.sublist(startIndex).toList(growable: true);
    if (selectedLines.isNotEmpty) {
      final firstLine = selectedLines.first.trim();
      if (_isLegacyProgressTitle(firstLine) ||
          _displayTitlePattern.hasMatch(firstLine) ||
          _legacyDisplayTitlePattern.hasMatch(firstLine)) {
        selectedLines.removeAt(0);
      }
    }

    final content = selectedLines.join('\n').trim();
    return content.isEmpty ? null : content;
  }

  static bool _isLegacyProgressTitle(String line) {
    for (final pattern in _legacyProgressTitlePatterns) {
      if (pattern.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  static bool _isLegacyProgressMarker(String line) {
    for (final pattern in _legacyProgressMarkerPatterns) {
      if (pattern.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  static String _titleForType(String type) {
    switch (type) {
      case 'progress':
        return 'AI \u5b66\u4e60\u5206\u6790';
      case 'business':
        return 'AI \u7ecf\u8425\u6d1e\u5bdf';
      case 'handwriting':
        return 'AI 课堂作品分析';
      case 'student_insight':
        return 'AI 学生洞察';
      default:
        return 'AI \u5206\u6790';
    }
  }

  static String _formatDisplayTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$month-$day $hour:$minute';
  }
}
