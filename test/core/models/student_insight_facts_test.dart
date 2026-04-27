import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';
import 'package:moyun/core/models/student_insight_facts.dart';

void main() {
  group('StudentAttendanceInsightFacts', () {
    test('returns empty facts for empty records', () {
      final facts = StudentAttendanceInsightFacts.fromRecords(const []);

      expect(facts.totalReceivable, 0);
      expect(facts.lastFormalDate, isNull);
      expect(facts.hasTrial, isFalse);
      expect(facts.hasFormal, isFalse);
      expect(facts.latestUpdatedAt, isNull);
      expect(facts.recentScoredFormalRecords, isEmpty);
    });

    test('summarizes receivable, attendance flags and latest update', () {
      final facts = StudentAttendanceInsightFacts.fromRecords([
        _attendance(
          id: 'trial',
          status: 'trial',
          feeAmount: 50,
          date: '2026-04-01',
          updatedAt: 10,
        ),
        _attendance(
          id: 'absent',
          status: 'absent',
          feeAmount: 0,
          date: '2026-04-03',
          updatedAt: 30,
        ),
        _attendance(
          id: 'present',
          status: 'present',
          feeAmount: 100,
          date: '2026-04-02',
          updatedAt: 20,
        ),
      ]);

      expect(facts.totalReceivable, 150);
      expect(facts.lastFormalDate, '2026-04-02');
      expect(facts.hasTrial, isTrue);
      expect(facts.hasFormal, isTrue);
      expect(facts.latestUpdatedAt, 30);
    });

    test(
      'keeps only formal records with progress scores for progress insight',
      () {
        final facts = StudentAttendanceInsightFacts.fromRecords([
          _attendance(
            id: 'trial-scored',
            status: 'trial',
            progressScores: const AttendanceProgressScores(strokeQuality: 1),
          ),
          _attendance(id: 'present-unscored', status: 'present'),
          _attendance(
            id: 'late-scored',
            status: 'late',
            progressScores: const AttendanceProgressScores(strokeQuality: 2),
          ),
          _attendance(
            id: 'present-scored',
            status: 'present',
            progressScores: const AttendanceProgressScores(
              structureAccuracy: 3,
            ),
          ),
        ]);

        expect(facts.recentScoredFormalRecords.map((record) => record.id), [
          'late-scored',
          'present-scored',
        ]);
      },
    );

    test(
      'copyWith preserves aggregate fields while replacing scored records',
      () {
        final original = StudentAttendanceInsightFacts.fromRecords([
          _attendance(
            id: 'present-scored',
            status: 'present',
            feeAmount: 100,
            progressScores: const AttendanceProgressScores(strokeQuality: 2),
            updatedAt: 20,
          ),
        ]);
        final replacement = [
          _attendance(id: 'replacement', status: 'late', updatedAt: 30),
        ];

        final copied = original.copyWith(
          recentScoredFormalRecords: replacement,
        );

        expect(copied.totalReceivable, original.totalReceivable);
        expect(copied.lastFormalDate, original.lastFormalDate);
        expect(copied.hasFormal, original.hasFormal);
        expect(copied.latestUpdatedAt, original.latestUpdatedAt);
        expect(copied.recentScoredFormalRecords, replacement);
      },
    );
  });
}

Attendance _attendance({
  required String id,
  String status = 'present',
  double feeAmount = 0,
  String date = '2026-04-01',
  int updatedAt = 1,
  AttendanceProgressScores? progressScores,
}) {
  return Attendance(
    id: id,
    studentId: 'student-1',
    date: date,
    startTime: '09:00',
    endTime: '10:00',
    status: status,
    priceSnapshot: feeAmount,
    feeAmount: feeAmount,
    progressScores: progressScores,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}
