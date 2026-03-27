import 'dart:convert';

const kLessonFocusTagOptions = <String>[
  '偏旁结构',
  '控笔稳定',
  '起收笔法',
  '行气连贯',
  '章法布局',
  '墨色控制',
];

class AttendanceProgressScores {
  static const Object _unset = Object();

  final double? strokeQuality;
  final double? structureAccuracy;
  final double? rhythmConsistency;

  const AttendanceProgressScores({
    this.strokeQuality,
    this.structureAccuracy,
    this.rhythmConsistency,
  });

  bool get isEmpty =>
      strokeQuality == null &&
      structureAccuracy == null &&
      rhythmConsistency == null;

  Map<String, dynamic> toMap() => {
        'stroke_quality': strokeQuality,
        'structure_accuracy': structureAccuracy,
        'rhythm_consistency': rhythmConsistency,
      };

  factory AttendanceProgressScores.fromMap(Map<String, dynamic> map) {
    return AttendanceProgressScores(
      strokeQuality: _toDouble(map['stroke_quality']),
      structureAccuracy: _toDouble(map['structure_accuracy']),
      rhythmConsistency: _toDouble(map['rhythm_consistency']),
    );
  }

  AttendanceProgressScores copyWith({
    Object? strokeQuality = _unset,
    Object? structureAccuracy = _unset,
    Object? rhythmConsistency = _unset,
  }) {
    return AttendanceProgressScores(
      strokeQuality: identical(strokeQuality, _unset)
          ? this.strokeQuality
          : strokeQuality as double?,
      structureAccuracy: identical(structureAccuracy, _unset)
          ? this.structureAccuracy
          : structureAccuracy as double?,
      rhythmConsistency: identical(rhythmConsistency, _unset)
          ? this.rhythmConsistency
          : rhythmConsistency as double?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class AttendanceFeedbackCodec {
  const AttendanceFeedbackCodec._();

  static List<String> decodeFocusTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  static String? encodeFocusTags(List<String> tags) {
    final normalized = tags
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) return null;
    return jsonEncode(normalized);
  }

  static AttendanceProgressScores? decodeProgressScores(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final scores = AttendanceProgressScores.fromMap(decoded);
      return scores.isEmpty ? null : scores;
    } catch (_) {
      return null;
    }
  }

  static String? encodeProgressScores(AttendanceProgressScores? scores) {
    if (scores == null || scores.isEmpty) return null;
    return jsonEncode(scores.toMap());
  }
}
