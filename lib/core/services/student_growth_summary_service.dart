import '../models/attendance.dart';

class StudentGrowthSummary {
  final String progressPoint;
  final String attentionPoint;
  final String practiceSummary;
  final List<String> focusTags;
  final String latestLessonLabel;
  final String nextLessonLabel;
  final String latestProgressSummary;
  final String dataFreshness;

  const StudentGrowthSummary({
    required this.progressPoint,
    required this.attentionPoint,
    required this.practiceSummary,
    required this.focusTags,
    required this.latestLessonLabel,
    required this.nextLessonLabel,
    required this.latestProgressSummary,
    required this.dataFreshness,
  });
}

class StudentGrowthSummaryService {
  const StudentGrowthSummaryService();

  static const _dimensionLabels = <String, String>{
    'stroke_quality': '笔画质量',
    'structure_accuracy': '结构准确度',
    'rhythm_consistency': '节奏稳定性',
  };

  StudentGrowthSummary build({
    required List<Attendance> records,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final sortedRecords = [...records]..sort(_compareAttendance);
    final formalRecords = sortedRecords
        .where(
          (record) => record.status == 'present' || record.status == 'late',
        )
        .toList(growable: false);
    final latestFormalRecord = formalRecords.isEmpty
        ? null
        : formalRecords.last;
    final latestUpdatedAt = sortedRecords.isEmpty
        ? currentTime.millisecondsSinceEpoch
        : sortedRecords
              .map((record) => record.updatedAt)
              .reduce((left, right) => left > right ? left : right);
    final focusTags = _buildTopFocusTags(formalRecords);

    return StudentGrowthSummary(
      progressPoint: _buildProgressPoint(formalRecords, focusTags),
      attentionPoint: _buildAttentionPoint(latestFormalRecord, focusTags),
      practiceSummary: _buildPracticeSummary(sortedRecords, focusTags),
      focusTags: focusTags,
      latestLessonLabel: latestFormalRecord?.date ?? '暂无正式课程',
      nextLessonLabel: _buildNextLessonLabel(sortedRecords, currentTime),
      latestProgressSummary: _buildLatestProgressSummary(latestFormalRecord),
      dataFreshness: _formatTimestamp(latestUpdatedAt),
    );
  }

  int _compareAttendance(Attendance left, Attendance right) {
    final dateCompare = left.date.compareTo(right.date);
    if (dateCompare != 0) {
      return dateCompare;
    }
    return left.startTime.compareTo(right.startTime);
  }

  List<String> _buildTopFocusTags(List<Attendance> formalRecords) {
    final counts = <String, int>{};
    final recentRecords = formalRecords.reversed.take(8);
    for (final record in recentRecords) {
      for (final tag in record.lessonFocusTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }

    final entries = counts.entries.toList()
      ..sort((left, right) {
        final countCompare = right.value.compareTo(left.value);
        if (countCompare != 0) {
          return countCompare;
        }
        return left.key.compareTo(right.key);
      });
    return entries.take(4).map((entry) => entry.key).toList(growable: false);
  }

  String _buildProgressPoint(
    List<Attendance> formalRecords,
    List<String> focusTags,
  ) {
    final improvedDimensions = _buildImprovedDimensions(formalRecords);
    if (improvedDimensions.isNotEmpty) {
      return '近 3 次评分持续提升：${improvedDimensions.join('、')}';
    }

    if (formalRecords.isNotEmpty) {
      final latestScores = _extractScores(formalRecords.last);
      if (latestScores.isNotEmpty) {
        final strongest = latestScores.entries.reduce(
          (best, current) => current.value > best.value ? current : best,
        );
        final label = _dimensionLabels[strongest.key] ?? strongest.key;
        return '最近一次课堂中，$label表现更稳。';
      }
    }

    if (focusTags.isNotEmpty) {
      return '近期课堂重点集中在：${focusTags.join('、')}。';
    }

    return '近期课堂节奏稳定，可继续保持当前练习安排。';
  }

  String _buildAttentionPoint(
    Attendance? latestFormalRecord,
    List<String> focusTags,
  ) {
    if (latestFormalRecord != null) {
      final latestScores = _extractScores(latestFormalRecord);
      if (latestScores.isNotEmpty) {
        final weakest = latestScores.entries.reduce(
          (best, current) => current.value < best.value ? current : best,
        );
        final label = _dimensionLabels[weakest.key] ?? weakest.key;
        return '下一阶段继续巩固：$label。';
      }
    }

    if (focusTags.isNotEmpty) {
      return '下一阶段继续围绕 ${focusTags.first} 反复打磨。';
    }

    return '下一阶段继续保持基础控笔与日常临摹频率。';
  }

  String _buildPracticeSummary(
    List<Attendance> sortedRecords,
    List<String> focusTags,
  ) {
    for (final record in sortedRecords.reversed) {
      final note = record.homePracticeNote?.trim() ?? '';
      if (note.isNotEmpty) {
        return _truncate(note, 48);
      }
    }

    if (focusTags.isNotEmpty) {
      return '建议围绕 ${focusTags.join('、')} 做每日短时练习。';
    }

    return '建议保持每周稳定练习，并记录阶段性变化。';
  }

  String _buildNextLessonLabel(
    List<Attendance> sortedRecords,
    DateTime currentTime,
  ) {
    final nowKey = _toSortableDateTime(currentTime);
    for (final record in sortedRecords) {
      final recordKey = '${record.date} ${record.startTime}';
      if (recordKey.compareTo(nowKey) >= 0) {
        return '${record.date} ${record.startTime}-${record.endTime}';
      }
    }
    return '待确认';
  }

  String _buildLatestProgressSummary(Attendance? latestFormalRecord) {
    if (latestFormalRecord == null) {
      return '暂无评分记录';
    }
    final scores = _extractScores(latestFormalRecord);
    if (scores.isEmpty) {
      return '最近课堂暂未填写评分';
    }
    final parts = <String>[];
    for (final entry in _dimensionLabels.entries) {
      final value = scores[entry.key];
      if (value == null) {
        continue;
      }
      parts.add('${entry.value} ${value.toStringAsFixed(1)}');
    }
    return parts.join(' / ');
  }

  List<String> _buildImprovedDimensions(List<Attendance> formalRecords) {
    final snapshots = <Map<String, double>>[];
    for (final record in formalRecords) {
      final scores = _extractScores(record);
      if (scores.isEmpty) {
        continue;
      }
      snapshots.add(scores);
    }

    if (snapshots.length < 3) {
      return const <String>[];
    }

    final recentSnapshots = snapshots.sublist(snapshots.length - 3);
    final improved = <String>[];
    for (final entry in _dimensionLabels.entries) {
      final first = recentSnapshots[0][entry.key];
      final second = recentSnapshots[1][entry.key];
      final third = recentSnapshots[2][entry.key];
      if (first == null || second == null || third == null) {
        continue;
      }
      if (first < second && second < third) {
        improved.add(entry.value);
      }
    }
    return improved;
  }

  Map<String, double> _extractScores(Attendance record) {
    final progressScores = record.progressScores;
    if (progressScores == null || progressScores.isEmpty) {
      return const <String, double>{};
    }

    final result = <String, double>{};
    final raw = progressScores.toMap();
    for (final key in _dimensionLabels.keys) {
      final value = raw[key];
      if (value is num) {
        result[key] = value.toDouble();
      }
    }
    return result;
  }

  String _formatTimestamp(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }

  String _toSortableDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }

  String _truncate(String value, int maxLength) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 1)}…';
  }
}
