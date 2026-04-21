import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';

void main() {
  group('buildStudentAttendanceInsightFactsByStudent', () {
    test('maps aggregate SQL aliases into student insight facts', () {
      final factsByStudent = buildStudentAttendanceInsightFactsByStudent(
        aggregateRows: const [
          {
            'student_id': 'student-1',
            'total_receivable': 320.5,
            'latest_updated_at': 30,
            'last_formal_date': '2026-04-10',
            'trial_count': 1,
            'formal_count': 2,
          },
          {
            'student_id': 'student-2',
            'total_receivable': 0,
            'latest_updated_at': null,
            'last_formal_date': null,
            'trial_count': 0,
            'formal_count': 0,
          },
        ],
        scoredRows: const [],
      );

      final first = factsByStudent['student-1']!;
      expect(first.totalReceivable, 320.5);
      expect(first.latestUpdatedAt, 30);
      expect(first.lastFormalDate, '2026-04-10');
      expect(first.hasTrial, isTrue);
      expect(first.hasFormal, isTrue);

      final second = factsByStudent['student-2']!;
      expect(second.totalReceivable, 0);
      expect(second.latestUpdatedAt, isNull);
      expect(second.lastFormalDate, isNull);
      expect(second.hasTrial, isFalse);
      expect(second.hasFormal, isFalse);
    });

    test('keeps only the first three scored rows per aggregated student', () {
      final factsByStudent = buildStudentAttendanceInsightFactsByStudent(
        aggregateRows: const [
          {
            'student_id': 'student-1',
            'total_receivable': 400,
            'latest_updated_at': 40,
            'last_formal_date': '2026-04-22',
            'trial_count': 0,
            'formal_count': 4,
          },
        ],
        scoredRows: [
          _attendanceRow('score-4', date: '2026-04-22', updatedAt: 40),
          _attendanceRow('score-3', date: '2026-04-15', updatedAt: 30),
          _attendanceRow('score-2', date: '2026-04-08', updatedAt: 20),
          _attendanceRow('score-1', date: '2026-04-01', updatedAt: 10),
          _attendanceRow(
            'other-student-score',
            studentId: 'student-2',
            date: '2026-04-22',
            updatedAt: 40,
          ),
        ],
      );

      expect(
        factsByStudent['student-1']!.recentScoredFormalRecords.map(
          (record) => record.id,
        ),
        ['score-4', 'score-3', 'score-2'],
      );
      expect(factsByStudent.containsKey('student-2'), isFalse);
    });
  });
}

Map<String, Object?> _attendanceRow(
  String id, {
  String studentId = 'student-1',
  required String date,
  required int updatedAt,
}) {
  return Attendance(
    id: id,
    studentId: studentId,
    date: date,
    startTime: '09:00',
    endTime: '10:00',
    status: 'present',
    priceSnapshot: 100,
    feeAmount: 100,
    progressScores: const AttendanceProgressScores(strokeQuality: 3),
    createdAt: updatedAt,
    updatedAt: updatedAt,
  ).toMap();
}
