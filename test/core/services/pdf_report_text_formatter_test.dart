import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';
import 'package:moyun/core/services/pdf_report_text_formatter.dart';

void main() {
  group('PdfReportTextFormatter.formatDuration', () {
    test('returns zero minutes for non-positive durations', () {
      expect(PdfReportTextFormatter.formatDuration(0), '0分钟');
      expect(PdfReportTextFormatter.formatDuration(-15), '0分钟');
    });

    test('formats minutes and hours exactly', () {
      expect(PdfReportTextFormatter.formatDuration(45), '45分钟');
      expect(PdfReportTextFormatter.formatDuration(60), '1小时');
      expect(PdfReportTextFormatter.formatDuration(135), '2小时 15分钟');
    });
  });

  group('PdfReportTextFormatter.formatStatusLabel', () {
    test('maps known attendance statuses', () {
      expect(PdfReportTextFormatter.formatStatusLabel('present'), '出勤');
      expect(PdfReportTextFormatter.formatStatusLabel('late'), '迟到');
      expect(PdfReportTextFormatter.formatStatusLabel('leave'), '请假');
      expect(PdfReportTextFormatter.formatStatusLabel('absent'), '缺勤');
      expect(PdfReportTextFormatter.formatStatusLabel('trial'), '试听');
    });

    test('preserves unknown status values', () {
      expect(PdfReportTextFormatter.formatStatusLabel('custom'), 'custom');
    });
  });

  group('PdfReportTextFormatter.formatLessonFocusTags', () {
    test('returns empty string when no focus tags exist', () {
      expect(
        PdfReportTextFormatter.formatLessonFocusTags(_attendance()),
        isEmpty,
      );
    });

    test('joins lesson focus tags with comma and space', () {
      expect(
        PdfReportTextFormatter.formatLessonFocusTags(
          _attendance(lessonFocusTags: ['偏旁结构', '控笔稳定']),
        ),
        '偏旁结构, 控笔稳定',
      );
    });
  });

  group('PdfReportTextFormatter.formatProgressSummary', () {
    test('returns empty string when no structured scores exist', () {
      expect(
        PdfReportTextFormatter.formatProgressSummary(_attendance()),
        isEmpty,
      );
    });

    test('formats available progress scores in fixed order', () {
      expect(
        PdfReportTextFormatter.formatProgressSummary(
          _attendance(
            progressScores: const AttendanceProgressScores(
              strokeQuality: 4,
              structureAccuracy: 3.25,
              rhythmConsistency: 2.0,
            ),
          ),
        ),
        '笔画质量：4.0 / 结构准确度：3.3 / 节奏稳定性：2.0',
      );
    });

    test('skips missing score fields without changing separators', () {
      expect(
        PdfReportTextFormatter.formatProgressSummary(
          _attendance(
            progressScores: const AttendanceProgressScores(
              structureAccuracy: 4.4,
            ),
          ),
        ),
        '结构准确度：4.4',
      );
    });
  });

  group('PdfReportTextFormatter.splitAiAnalysisParagraphs', () {
    test('returns empty list for empty input', () {
      expect(PdfReportTextFormatter.splitAiAnalysisParagraphs(''), isEmpty);
    });

    test('splits by blank lines before other strategies', () {
      expect(
        PdfReportTextFormatter.splitAiAnalysisParagraphs(
          '  第一段  \n\n  第二段\n\n第三段  ',
        ),
        ['第一段', '第二段', '第三段'],
      );
    });

    test('splits by non-blank lines when only single newlines exist', () {
      expect(
        PdfReportTextFormatter.splitAiAnalysisParagraphs('第一行\n第二行\n第三行'),
        ['第一行', '第二行', '第三行'],
      );
    });

    test('falls back to sentence boundaries when no line breaks exist', () {
      expect(
        PdfReportTextFormatter.splitAiAnalysisParagraphs('专注度提升。结构更稳定！继续保持?'),
        ['专注度提升。', '结构更稳定！', '继续保持?'],
      );
    });

    test('returns original text when no split strategy applies', () {
      expect(PdfReportTextFormatter.splitAiAnalysisParagraphs('单段总结'), [
        '单段总结',
      ]);
    });
  });
}

Attendance _attendance({
  List<String> lessonFocusTags = const <String>[],
  AttendanceProgressScores? progressScores,
}) {
  return Attendance(
    id: 'a1',
    studentId: 's1',
    date: '2026-04-01',
    startTime: '10:00',
    endTime: '11:00',
    status: 'present',
    priceSnapshot: 100,
    feeAmount: 100,
    lessonFocusTags: lessonFocusTags,
    progressScores: progressScores,
    createdAt: 1,
    updatedAt: 1,
  );
}
