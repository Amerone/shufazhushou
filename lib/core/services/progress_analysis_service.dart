import '../models/attendance.dart';
import '../models/progress_analysis_result.dart';
import '../models/student.dart';
import 'vision_analysis_gateway.dart';

class ProgressAnalysisService {
  final VisionAnalysisGateway gateway;

  const ProgressAnalysisService({required this.gateway});

  Future<ProgressAnalysisResult> analyzeStudentProgress(
    Student student,
    List<Attendance> attendanceRecords, {
    double temperature = 0.2,
  }) async {
    final recentRecords = _recentRecords(attendanceRecords);
    if (recentRecords.isEmpty) {
      throw const VisionAnalysisException('该学员暂无可分析的近期出勤记录。');
    }

    final result = await gateway.analyzeText(
      TextAnalysisRequest(
        prompt: buildPrompt(student, recentRecords),
        temperature: temperature,
      ),
    );

    return ProgressAnalysisResult.fromVisionResult(
      model: result.model,
      rawText: result.text,
    );
  }

  static String buildPrompt(Student student, List<Attendance> recentRecords) {
    final lines = <String>[
      '你是一位书法教学分析助手，请根据学员近期课堂记录总结学习进展并给出教学建议。',
      '学员：${student.name}',
      '状态：${student.status == 'active' ? '在读' : '停课'}',
      '课时单价：¥${student.pricePerClass.toStringAsFixed(0)}',
      '记录数量：${recentRecords.length} 条最近课时记录',
      '',
      '近期课堂记录：',
    ];

    for (var i = 0; i < recentRecords.length; i++) {
      lines.add('${i + 1}. ${_recordLine(recentRecords[i])}');
    }

    lines.addAll(const [
      '',
      '请只输出一个 JSON 对象，不要添加 markdown 代码块，也不要输出额外说明。',
      'JSON 结构如下：',
      '{',
      '  "overall_assessment": "总体评价（1-2句）",',
      '  "trend_analysis": "趋势分析",',
      '  "strengths": "优势方面",',
      '  "areas_to_improve": "需加强方面",',
      '  "teaching_suggestions": ["教学建议1", "教学建议2", "教学建议3"]',
      '}',
      '要求：',
      '- 所有字段都使用中文。',
      '- 无法判断时返回保守结论，不要编造。',
      '- teaching_suggestions 固定返回 3 条，且要具体可执行。',
      '- 语言简洁、专业，避免空泛表述。',
    ]);

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

    return sorted.take(10).toList(growable: false)..sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return a.startTime.compareTo(b.startTime);
    });
  }

  static String _recordLine(Attendance record) {
    final focus = record.lessonFocusTags.isEmpty
        ? '无'
        : record.lessonFocusTags.join('、');
    final note = (record.note ?? '').trim().isEmpty ? '无' : record.note!.trim();
    final practice = (record.homePracticeNote ?? '').trim().isEmpty
        ? '无'
        : record.homePracticeNote!.trim();
    final scores = _formatScores(record);

    return '日期 ${record.date}，时间 ${record.startTime}-${record.endTime}，'
        '状态 ${_statusLabel(record.status)}，'
        '课堂重点 $focus，'
        '教师备注 $note，'
        '课后练习 $practice，'
        '三维评分 $scores。';
  }

  static String _formatScores(Attendance record) {
    final score = record.progressScores;
    if (score == null || score.isEmpty) return '无';

    final segments = <String>[];
    if (score.strokeQuality != null) {
      segments.add('笔画 ${score.strokeQuality!.toStringAsFixed(1)}');
    }
    if (score.structureAccuracy != null) {
      segments.add('结构 ${score.structureAccuracy!.toStringAsFixed(1)}');
    }
    if (score.rhythmConsistency != null) {
      segments.add('节奏 ${score.rhythmConsistency!.toStringAsFixed(1)}');
    }
    return segments.isEmpty ? '无' : segments.join('、');
  }

  static String _statusLabel(String status) {
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
}
