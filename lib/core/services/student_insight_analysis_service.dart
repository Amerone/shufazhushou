import '../models/ai_analysis_note_entry.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/student_insight_result.dart';
import 'ai_analysis_note_codec.dart';
import 'student_growth_summary_service.dart';
import 'vision_analysis_gateway.dart';

class StudentInsightAnalysisService {
  static const _maxRecentRecords = 12;
  static const _maxHandwritingEntries = 3;

  final VisionAnalysisGateway gateway;

  const StudentInsightAnalysisService({required this.gateway});

  Future<StudentInsightResult> analyzeStudentInsight(
    Student student,
    List<Attendance> attendanceRecords, {
    double temperature = 0.2,
    DateTime? now,
  }) async {
    final recentRecords = _recentRecords(attendanceRecords);
    final handwritingEntries = _handwritingEntries(student.note);
    if (recentRecords.isEmpty && handwritingEntries.isEmpty) {
      throw const VisionAnalysisException('该学生暂无可用于分析的课堂或作品数据。');
    }

    final result = await gateway.analyzeText(
      TextAnalysisRequest(
        prompt: buildPrompt(
          student,
          recentRecords,
          handwritingEntries: handwritingEntries,
          savedProgressInsight: AiAnalysisNoteCodec.latestContent(
            student.note,
            type: 'progress',
          ),
          now: now,
        ),
        temperature: temperature,
      ),
    );

    return StudentInsightResult.fromVisionResult(
      model: result.model,
      rawText: result.text,
    );
  }

  static String buildPrompt(
    Student student,
    List<Attendance> recentRecords, {
    List<AiAnalysisNoteEntry> handwritingEntries =
        const <AiAnalysisNoteEntry>[],
    String? savedProgressInsight,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final growthSummary = const StudentGrowthSummaryService().build(
      records: recentRecords,
      now: currentTime,
    );
    final attendancePatternLines = _buildAttendancePatternLines(
      recentRecords,
      currentTime,
    );
    final progressTrendLines = _buildProgressTrendLines(recentRecords);
    final lessonSnapshotLines = _buildLessonSnapshotLines(recentRecords);
    final handwritingLines = _buildHandwritingLines(handwritingEntries);
    final savedProgressText = (savedProgressInsight ?? '').trim();

    final lines = <String>[
      '你是书法老师的学生洞察助手。请结合学生的出勤规律、课堂重点、课后练习和已保存的作品分析，给出老师真正可用的洞察。',
      '学生：${student.name}',
      '状态：${student.status == 'active' ? '在读' : '停课'}',
      '课时单价：¥${student.pricePerClass.toStringAsFixed(0)}',
      '最近用于分析的课堂记录：${recentRecords.length} 条',
      '',
      '出勤规律摘要：',
      if (attendancePatternLines.isEmpty)
        '- 暂无出勤规律数据'
      else
        ...attendancePatternLines,
      '',
      '课堂成长摘要：',
      '- 最近上课：${growthSummary.latestLessonLabel}',
      '- 下次课参考：${growthSummary.nextLessonLabel}',
      '- 当前进步点：${growthSummary.progressPoint}',
      '- 当前待巩固点：${growthSummary.attentionPoint}',
      '- 最近练习建议：${growthSummary.practiceSummary}',
      '- 最近评分摘要：${growthSummary.latestProgressSummary}',
      if (growthSummary.focusTags.isNotEmpty)
        '- 最近高频课堂重点：${growthSummary.focusTags.join('、')}',
      '',
      '结构化评分趋势：',
      if (progressTrendLines.isEmpty)
        '- 最近缺少足够的评分数据'
      else
        ...progressTrendLines,
      '',
      '最近课堂记录：',
      if (lessonSnapshotLines.isEmpty) '- 暂无课堂记录' else ...lessonSnapshotLines,
      '',
      '最近保存的课堂作品分析：',
      if (handwritingLines.isEmpty) '- 暂无已保存的作品分析' else ...handwritingLines,
      '',
      '最近保存的 AI 学习分析：',
      savedProgressText.isEmpty ? '- 暂无已保存的学习分析' : '- $savedProgressText',
      '',
      '请只输出一个 JSON 对象，不要输出 markdown 代码块，也不要输出额外解释。',
      'JSON 结构如下：',
      '{',
      '  "summary": "学生总体画像，1-2句",',
      '  "attendance_pattern": "上课规律与稳定性判断",',
      '  "writing_observation": "结合作品分析，总结字体优势与短板",',
      '  "progress_insight": "是否在进步、卡在哪个环节",',
      '  "risk_alerts": ["风险提醒1", "风险提醒2"],',
      '  "teaching_suggestions": ["教学建议1", "教学建议2", "教学建议3"],',
      '  "parent_communication_tip": "给家长的沟通建议"',
      '}',
      '要求：',
      '- 所有字段都使用中文。',
      '- 没有证据的地方请明确保守，不要编造。',
      '- teaching_suggestions 固定返回 3 条，并且要具体、可执行。',
      '- parent_communication_tip 要适合老师直接转述给家长，不要太书面。',
      '- 不要重复抄写输入，重点做归纳、判断和下一步建议。',
    ];

    return lines.join('\n');
  }

  static List<Attendance> _recentRecords(List<Attendance> records) {
    if (records.isEmpty) return const <Attendance>[];

    final sorted = [...records]
      ..sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.startTime.compareTo(a.startTime);
      });

    return sorted.take(_maxRecentRecords).toList(growable: false)..sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return a.startTime.compareTo(b.startTime);
    });
  }

  static List<AiAnalysisNoteEntry> _handwritingEntries(String? note) {
    final entries = AiAnalysisNoteCodec.decodeEntries(
      note,
    ).where((entry) => entry.type == 'handwriting').toList(growable: false);
    if (entries.length <= _maxHandwritingEntries) {
      return entries;
    }
    return entries.sublist(entries.length - _maxHandwritingEntries);
  }

  static List<String> _buildAttendancePatternLines(
    List<Attendance> records,
    DateTime now,
  ) {
    if (records.isEmpty) return const <String>[];

    final formalRecords = records
        .where(
          (record) => record.status == 'present' || record.status == 'late',
        )
        .toList(growable: false);
    final lateCount = records.where((record) => record.status == 'late').length;
    final leaveCount = records
        .where((record) => record.status == 'leave')
        .length;
    final absentCount = records
        .where((record) => record.status == 'absent')
        .length;
    final trialCount = records
        .where((record) => record.status == 'trial')
        .length;
    final weekdayLabel = _topWeekdays(formalRecords);
    final timeLabel = _topStartTimes(formalRecords);
    final lastFormalDate = formalRecords.isEmpty
        ? null
        : formalRecords.last.date;

    return <String>[
      '- 正式上课 ${formalRecords.length} 次，迟到 $lateCount 次，请假 $leaveCount 次，缺勤 $absentCount 次，试听 $trialCount 次',
      if (lastFormalDate != null)
        '- 最近一次正式上课：$lastFormalDate，距今约 ${_daysSince(lastFormalDate, now)} 天',
      if (weekdayLabel.isNotEmpty) '- 常见上课日：$weekdayLabel',
      if (timeLabel.isNotEmpty) '- 常见上课时段：$timeLabel',
      if (formalRecords.length >= 2)
        '- 正式上课平均间隔约 ${_averageGapDays(formalRecords).toStringAsFixed(1)} 天',
    ];
  }

  static List<String> _buildProgressTrendLines(List<Attendance> records) {
    final scoredRecords = records
        .where(
          (record) =>
              record.progressScores != null && !record.progressScores!.isEmpty,
        )
        .toList(growable: false);
    if (scoredRecords.length < 2) return const <String>[];

    const labels = <String, String>{
      'stroke': '笔画',
      'structure': '结构',
      'rhythm': '节奏',
    };
    final recent = scoredRecords.reversed.take(3).toList(growable: false);
    final baseline = scoredRecords.length > 3
        ? scoredRecords
              .take(scoredRecords.length - recent.length)
              .toList(growable: false)
        : scoredRecords.take(scoredRecords.length - 1).toList(growable: false);
    if (baseline.isEmpty) return const <String>[];

    final result = <String>[];
    for (final entry in labels.entries) {
      final recentAverage = _averageScore(recent, entry.key);
      final baselineAverage = _averageScore(baseline, entry.key);
      if (recentAverage == null || baselineAverage == null) {
        continue;
      }
      final delta = recentAverage - baselineAverage;
      final direction = delta > 0.15
          ? '提升'
          : delta < -0.15
          ? '回落'
          : '基本持平';
      final deltaLabel = delta >= 0
          ? '+${delta.toStringAsFixed(1)}'
          : delta.toStringAsFixed(1);
      result.add(
        '- ${entry.value}评分：近期 ${recentAverage.toStringAsFixed(1)}，对比前段 ${baselineAverage.toStringAsFixed(1)}（$direction，$deltaLabel）',
      );
    }
    return result;
  }

  static List<String> _buildLessonSnapshotLines(List<Attendance> records) {
    if (records.isEmpty) return const <String>[];

    final snapshots = records.reversed.take(4).map((record) {
      final focus = record.lessonFocusTags.isEmpty
          ? '无重点标签'
          : record.lessonFocusTags.join('、');
      final practice = _compressText(record.homePracticeNote, 48);
      final note = _compressText(record.note, 40);
      return '- ${record.date} ${record.startTime}-${record.endTime}，状态 ${_statusLabel(record.status)}，重点 $focus，课后练习 ${practice ?? '无'}，备注 ${note ?? '无'}';
    });
    return snapshots.toList(growable: false);
  }

  static List<String> _buildHandwritingLines(
    List<AiAnalysisNoteEntry> handwritingEntries,
  ) {
    if (handwritingEntries.isEmpty) return const <String>[];
    return handwritingEntries
        .map((entry) {
          final content = _compressMultiline(entry.content, 120);
          return '- ${_formatDateTime(entry.createdAt)}：$content';
        })
        .toList(growable: false);
  }

  static String _topWeekdays(List<Attendance> records) {
    final counts = <int, int>{};
    for (final record in records) {
      final weekday = DateTime.tryParse(record.date)?.weekday;
      if (weekday == null) continue;
      counts[weekday] = (counts[weekday] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';

    final entries = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return entries.take(2).map((entry) => _weekdayLabel(entry.key)).join('、');
  }

  static String _topStartTimes(List<Attendance> records) {
    final counts = <String, int>{};
    for (final record in records) {
      counts[record.startTime] = (counts[record.startTime] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';

    final entries = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return entries.take(2).map((entry) => entry.key).join('、');
  }

  static double _averageGapDays(List<Attendance> records) {
    if (records.length < 2) return 0;
    final sorted = [...records]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });
    var totalGap = 0;
    var totalCount = 0;
    for (var i = 1; i < sorted.length; i++) {
      final previous = DateTime.tryParse(sorted[i - 1].date);
      final current = DateTime.tryParse(sorted[i].date);
      if (previous == null || current == null) continue;
      totalGap += current.difference(previous).inDays;
      totalCount += 1;
    }
    if (totalCount == 0) return 0;
    return totalGap / totalCount;
  }

  static int _daysSince(String date, DateTime now) {
    final target = DateTime.tryParse(date);
    if (target == null) return 0;
    return now.difference(target).inDays;
  }

  static double? _averageScore(List<Attendance> records, String dimension) {
    final values = <double>[];
    for (final record in records) {
      final scores = record.progressScores;
      if (scores == null) continue;
      final value = switch (dimension) {
        'stroke' => scores.strokeQuality,
        'structure' => scores.structureAccuracy,
        'rhythm' => scores.rhythmConsistency,
        _ => null,
      };
      if (value != null) {
        values.add(value);
      }
    }
    if (values.isEmpty) return null;
    final total = values.reduce((a, b) => a + b);
    return total / values.length;
  }

  static String _weekdayLabel(int weekday) {
    return switch (weekday) {
      DateTime.monday => '周一',
      DateTime.tuesday => '周二',
      DateTime.wednesday => '周三',
      DateTime.thursday => '周四',
      DateTime.friday => '周五',
      DateTime.saturday => '周六',
      DateTime.sunday => '周日',
      _ => '未知',
    };
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'present' => '出勤',
      'late' => '迟到',
      'leave' => '请假',
      'absent' => '缺勤',
      'trial' => '试听',
      _ => status,
    };
  }

  static String? _compressText(String? value, int maxLength) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (normalized.isEmpty) return null;
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 1)}…';
  }

  static String _compressMultiline(String value, int maxLength) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 1)}…';
  }

  static String _formatDateTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$month-$day $hour:$minute';
  }
}
