import '../models/ai_analysis_note_entry.dart';
import '../models/attendance.dart';
import '../models/student_artwork_timeline_entry.dart';
import '../services/ai_analysis_note_codec.dart';

class StudentArtworkTimelineService {
  const StudentArtworkTimelineService();

  List<StudentArtworkTimelineEntry> build({
    required String? studentNote,
    required List<Attendance> records,
  }) {
    final handwritingEntries = AiAnalysisNoteCodec.decodeEntries(
      studentNote,
    ).where((entry) => entry.type == 'handwriting').toList(growable: false);
    if (handwritingEntries.isEmpty) {
      return const <StudentArtworkTimelineEntry>[];
    }

    final resolved =
        handwritingEntries
            .map((entry) => _resolveEntry(entry, records))
            .toList(growable: false)
          ..sort((left, right) => right.sortTime.compareTo(left.sortTime));

    final timeline = <StudentArtworkTimelineEntry>[];
    for (var index = 0; index < resolved.length; index++) {
      final current = resolved[index];
      final older = index + 1 < resolved.length ? resolved[index + 1] : null;

      timeline.add(
        StudentArtworkTimelineEntry(
          createdAt: current.noteEntry.createdAt,
          lessonDate: current.lessonDate,
          lessonTimeRange: current.lessonTimeRange,
          summary: current.summary,
          strokeObservation: current.strokeObservation,
          structureObservation: current.structureObservation,
          layoutObservation: current.layoutObservation,
          practiceSuggestions: current.practiceSuggestions,
          focusTags: current.attendance?.lessonFocusTags ?? const <String>[],
          progressLabel: _buildProgressLabel(
            current,
            older,
            totalCount: resolved.length,
            index: index,
          ),
          scoreSummary: _buildScoreSummary(current.attendance),
        ),
      );
    }

    return timeline;
  }

  _ResolvedArtworkEntry _resolveEntry(
    AiAnalysisNoteEntry entry,
    List<Attendance> records,
  ) {
    final lessonStamp = _extractField(entry.content, '课堂日期');
    final parsedLesson = _parseLessonStamp(lessonStamp);
    final attendance = _matchAttendance(records, parsedLesson);

    final lessonDate =
        parsedLesson.date ?? attendance?.date ?? _formatDate(entry.createdAt);
    final lessonTimeRange = parsedLesson.timeRange.isNotEmpty
        ? parsedLesson.timeRange
        : attendance == null
        ? ''
        : '${attendance.startTime}-${attendance.endTime}';
    final sortTime =
        _resolveLessonDateTime(parsedLesson.date, parsedLesson.startTime) ??
        _attendanceDateTime(attendance) ??
        entry.createdAt;

    return _ResolvedArtworkEntry(
      noteEntry: entry,
      lessonDate: lessonDate,
      lessonTimeRange: lessonTimeRange,
      summary: _extractField(entry.content, '总体概览'),
      strokeObservation: _extractField(entry.content, '笔画观察'),
      structureObservation: _extractField(entry.content, '结构观察'),
      layoutObservation: _extractField(entry.content, '章法观察'),
      practiceSuggestions: _extractNumberedSection(entry.content, '练习建议'),
      attendance: attendance,
      sortTime: sortTime,
    );
  }

  Attendance? _matchAttendance(
    List<Attendance> records,
    _ParsedLessonStamp lesson,
  ) {
    if (records.isEmpty) {
      return null;
    }

    for (final record in records) {
      if (lesson.date == null || record.date != lesson.date) {
        continue;
      }
      if (lesson.timeRange.isEmpty ||
          '${record.startTime}-${record.endTime}' == lesson.timeRange) {
        return record;
      }
    }

    if (lesson.date == null) {
      return null;
    }

    for (final record in records) {
      if (record.date == lesson.date) {
        return record;
      }
    }
    return null;
  }

  String _buildProgressLabel(
    _ResolvedArtworkEntry current,
    _ResolvedArtworkEntry? older, {
    required int totalCount,
    required int index,
  }) {
    final currentAverage = _scoreAverage(current.attendance);
    final olderAverage = _scoreAverage(older?.attendance);

    if (currentAverage != null && olderAverage != null) {
      final delta = currentAverage - olderAverage;
      if (delta >= 0.35) {
        return '较上次更稳';
      }
      if (delta <= -0.35) {
        return '较上次有波动';
      }
      return '与上次接近';
    }

    if (index == totalCount - 1) {
      return '首次作品记录';
    }
    return '已连续记录 ${totalCount - index} 次作品';
  }

  String _buildScoreSummary(Attendance? attendance) {
    final scores = attendance?.progressScores;
    if (scores == null || scores.isEmpty) {
      return '';
    }

    final parts = <String>[];
    if (scores.strokeQuality != null) {
      parts.add('笔画 ${scores.strokeQuality!.toStringAsFixed(1)}');
    }
    if (scores.structureAccuracy != null) {
      parts.add('结构 ${scores.structureAccuracy!.toStringAsFixed(1)}');
    }
    if (scores.rhythmConsistency != null) {
      parts.add('节奏 ${scores.rhythmConsistency!.toStringAsFixed(1)}');
    }
    return parts.join(' / ');
  }

  double? _scoreAverage(Attendance? attendance) {
    final scores = attendance?.progressScores;
    if (scores == null || scores.isEmpty) {
      return null;
    }

    final values = <double>[
      if (scores.strokeQuality != null) scores.strokeQuality!,
      if (scores.structureAccuracy != null) scores.structureAccuracy!,
      if (scores.rhythmConsistency != null) scores.rhythmConsistency!,
    ];
    if (values.isEmpty) {
      return null;
    }
    final sum = values.fold<double>(0, (total, value) => total + value);
    return sum / values.length;
  }

  String _extractField(String content, String label) {
    final prefixPattern = RegExp('^$label[：:]\\s*(.*)\$');
    for (final rawLine in content.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      final match = prefixPattern.firstMatch(line);
      if (match != null) {
        return (match.group(1) ?? '').trim();
      }
    }
    return '';
  }

  List<String> _extractNumberedSection(String content, String label) {
    final lines = content
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .toList(growable: false);
    final result = <String>[];
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
        result.add(line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim());
        continue;
      }

      if (RegExp('^$label[：:]').hasMatch(line)) {
        collecting = true;
      }
    }

    return result.where((item) => item.isNotEmpty).toList(growable: false);
  }

  _ParsedLessonStamp _parseLessonStamp(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return const _ParsedLessonStamp();
    }

    final match = RegExp(
      r'(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}:\d{2})-(\d{2}:\d{2}))?',
    ).firstMatch(value);
    if (match == null) {
      return const _ParsedLessonStamp();
    }

    final date = match.group(1);
    final startTime = match.group(2);
    final endTime = match.group(3);
    return _ParsedLessonStamp(
      date: date,
      startTime: startTime,
      timeRange: startTime != null && endTime != null
          ? '$startTime-$endTime'
          : '',
    );
  }

  DateTime? _resolveLessonDateTime(String? date, String? startTime) {
    if (date == null) {
      return null;
    }
    final raw = startTime == null
        ? '${date}T00:00:00'
        : '${date}T$startTime:00';
    return DateTime.tryParse(raw);
  }

  DateTime? _attendanceDateTime(Attendance? attendance) {
    if (attendance == null) {
      return null;
    }
    return _resolveLessonDateTime(attendance.date, attendance.startTime);
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _ResolvedArtworkEntry {
  final AiAnalysisNoteEntry noteEntry;
  final String lessonDate;
  final String lessonTimeRange;
  final String summary;
  final String strokeObservation;
  final String structureObservation;
  final String layoutObservation;
  final List<String> practiceSuggestions;
  final Attendance? attendance;
  final DateTime sortTime;

  const _ResolvedArtworkEntry({
    required this.noteEntry,
    required this.lessonDate,
    required this.lessonTimeRange,
    required this.summary,
    required this.strokeObservation,
    required this.structureObservation,
    required this.layoutObservation,
    required this.practiceSuggestions,
    required this.attendance,
    required this.sortTime,
  });
}

class _ParsedLessonStamp {
  final String? date;
  final String? startTime;
  final String timeRange;

  const _ParsedLessonStamp({this.date, this.startTime, this.timeRange = ''});
}
