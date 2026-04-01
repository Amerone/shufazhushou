import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';
import 'package:moyun/core/services/ai_analysis_note_codec.dart';
import 'package:moyun/core/services/student_artwork_timeline_service.dart';

void main() {
  const service = StudentArtworkTimelineService();

  test(
    'builds timeline entries from handwriting notes and progress scores',
    () {
      final note = AiAnalysisNoteCodec.appendHandwritingAnalysis(
        existingNote: AiAnalysisNoteCodec.appendHandwritingAnalysis(
          existingNote: null,
          analysisText:
              '课堂日期：2026-03-20 18:00-19:30\n'
              '总体概览：结构开始稳定，但起收笔还不够干净\n'
              '笔画观察：横画收笔偏飘\n'
              '结构观察：重心开始回到中线\n'
              '练习建议：\n'
              '1. 每天单独练横画 10 次',
          analyzedAt: DateTime(2026, 3, 20, 21, 0),
        ),
        analysisText:
            '课堂日期：2026-03-27 18:00-19:30\n'
            '总体概览：结构更稳，字形收得更集中\n'
            '笔画观察：起收笔更利落\n'
            '结构观察：左右留白更均衡\n'
            '章法观察：整行节奏更顺\n'
            '练习建议：\n'
            '1. 保持起收笔节奏\n'
            '2. 临摹时继续检查中宫',
        analyzedAt: DateTime(2026, 3, 27, 21, 0),
      );

      final entries = service.build(
        studentNote: note,
        records: [
          Attendance(
            id: 'r-1',
            studentId: 'student-1',
            date: '2026-03-20',
            startTime: '18:00',
            endTime: '19:30',
            status: 'present',
            priceSnapshot: 200,
            feeAmount: 200,
            lessonFocusTags: const ['结构', '控笔'],
            progressScores: const AttendanceProgressScores(
              strokeQuality: 3.1,
              structureAccuracy: 3.4,
              rhythmConsistency: 3.0,
            ),
            createdAt: 1,
            updatedAt: 1,
          ),
          Attendance(
            id: 'r-2',
            studentId: 'student-1',
            date: '2026-03-27',
            startTime: '18:00',
            endTime: '19:30',
            status: 'present',
            priceSnapshot: 200,
            feeAmount: 200,
            lessonFocusTags: const ['结构', '章法'],
            progressScores: const AttendanceProgressScores(
              strokeQuality: 3.8,
              structureAccuracy: 4.1,
              rhythmConsistency: 3.7,
            ),
            createdAt: 2,
            updatedAt: 2,
          ),
        ],
      );

      expect(entries, hasLength(2));
      expect(entries.first.lessonLabel, '2026-03-27 18:00-19:30');
      expect(entries.first.progressLabel, '较上次更稳');
      expect(entries.first.scoreSummary, contains('结构 4.1'));
      expect(entries.first.focusTags, containsAll(<String>['结构', '章法']));
      expect(entries.first.practiceSuggestions, contains('保持起收笔节奏'));
      expect(entries.last.progressLabel, '首次作品记录');
    },
  );

  test('returns empty list when there is no handwriting note', () {
    expect(
      service.build(studentNote: null, records: const <Attendance>[]),
      isEmpty,
    );
  });
}
