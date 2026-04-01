import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';
import 'package:moyun/core/services/student_growth_summary_service.dart';

void main() {
  const service = StudentGrowthSummaryService();

  test('builds progress and practice summaries from recent records', () {
    final summary = service.build(
      records: [
        Attendance(
          id: 'r-1',
          studentId: 'student-1',
          date: '2026-03-01',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          lessonFocusTags: ['控笔', '结构'],
          progressScores: AttendanceProgressScores(
            strokeQuality: 2,
            structureAccuracy: 2,
          ),
          createdAt: 1,
          updatedAt: 1,
        ),
        Attendance(
          id: 'r-2',
          studentId: 'student-1',
          date: '2026-03-08',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          lessonFocusTags: ['控笔'],
          progressScores: AttendanceProgressScores(
            strokeQuality: 3,
            structureAccuracy: 3,
          ),
          createdAt: 2,
          updatedAt: 2,
        ),
        Attendance(
          id: 'r-3',
          studentId: 'student-1',
          date: '2026-03-15',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          lessonFocusTags: ['结构'],
          homePracticeNote: '每天临摹 15 分钟，重点检查起收笔。',
          progressScores: AttendanceProgressScores(
            strokeQuality: 4,
            structureAccuracy: 4,
          ),
          createdAt: 3,
          updatedAt: 3,
        ),
      ],
      now: DateTime(2026, 3, 20, 9, 0),
    );

    expect(summary.progressPoint, contains('近 3 次评分持续提升'));
    expect(summary.practiceSummary, contains('每天临摹 15 分钟'));
    expect(summary.focusTags, containsAll(<String>['控笔', '结构']));
    expect(summary.latestLessonLabel, '2026-03-15');
  });

  test('falls back gracefully when no structured feedback exists', () {
    final summary = service.build(
      records: [
        Attendance(
          id: 'r-4',
          studentId: 'student-2',
          date: '2026-03-10',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 10,
          updatedAt: 10,
        ),
      ],
      now: DateTime(2026, 3, 20, 9, 0),
    );

    expect(summary.progressPoint, isNotEmpty);
    expect(summary.attentionPoint, isNotEmpty);
    expect(summary.practiceSummary, isNotEmpty);
    expect(summary.nextLessonLabel, '待确认');
  });
}
