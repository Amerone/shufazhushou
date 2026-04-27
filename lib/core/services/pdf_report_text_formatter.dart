import '../models/attendance.dart';

class PdfReportTextFormatter {
  const PdfReportTextFormatter._();

  static String formatLessonFocusTags(Attendance record) {
    if (record.lessonFocusTags.isEmpty) return '';
    return record.lessonFocusTags.join(', ');
  }

  static String formatProgressSummary(Attendance record) {
    final scores = record.progressScores;
    if (scores == null || scores.isEmpty) return '';

    final parts = <String>[];
    if (scores.strokeQuality != null) {
      parts.add('笔画质量：${scores.strokeQuality!.toStringAsFixed(1)}');
    }
    if (scores.structureAccuracy != null) {
      parts.add('结构准确度：${scores.structureAccuracy!.toStringAsFixed(1)}');
    }
    if (scores.rhythmConsistency != null) {
      parts.add('节奏稳定性：${scores.rhythmConsistency!.toStringAsFixed(1)}');
    }
    return parts.join(' / ');
  }

  static String formatStatusLabel(String status) {
    switch (status) {
      case 'present':
        return '出勤';
      case 'late':
        return '迟到';
      case 'leave':
        return '请假';
      case 'absent':
        return '缺勤';
      case 'trial':
        return '试听';
      default:
        return status;
    }
  }

  static List<String> splitAiAnalysisParagraphs(String text) {
    if (text.isEmpty) return const [];

    final byBlankLine = text
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
    if (byBlankLine.length > 1) return byBlankLine;

    final byLine = text
        .split(RegExp(r'\n+'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
    if (byLine.length > 1) return byLine;

    final bySentence =
        RegExp(r'[^\u3002\uFF01\uFF1F!?]+[\u3002\uFF01\uFF1F!?]?')
            .allMatches(text)
            .map((match) => match.group(0)?.trim() ?? '')
            .where((paragraph) => paragraph.isNotEmpty)
            .toList(growable: false);
    if (bySentence.length > 1) return bySentence;

    return [text];
  }

  static String formatDuration(int minutes) {
    if (minutes <= 0) return '0分钟';
    if (minutes < 60) return '$minutes分钟';

    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours小时';
    return '$hours小时 $rest分钟';
  }
}
