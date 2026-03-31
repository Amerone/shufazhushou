import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';

void main() {
  group('Attendance structured feedback serialization', () {
    test('fromMap/toMap preserves structured feedback payload', () {
      final input = <String, dynamic>{
        'id': 'attendance-1',
        'student_id': 'student-1',
        'date': '2026-03-26',
        'start_time': '09:00',
        'end_time': '10:00',
        'status': 'present',
        'price_snapshot': 120.0,
        'fee_amount': 120.0,
        'note': '基础笔画稳定',
        'lesson_focus_tags': '["控笔","结构"]',
        'home_practice_note': '每天练习15分钟横竖撇捺',
        'progress_scores_json':
            '{"stroke_quality":4,"structure_accuracy":3,"rhythm_consistency":4}',
        'created_at': 1711411200000,
        'updated_at': 1711411200000,
      };

      final model = Attendance.fromMap(input);
      final roundTrip = model.toMap();

      expect(roundTrip['lesson_focus_tags'], input['lesson_focus_tags']);
      expect(roundTrip['home_practice_note'], input['home_practice_note']);
      expect(roundTrip['progress_scores_json'], input['progress_scores_json']);
    });

    test(
      'null structured feedback fields remain nullable on serialization',
      () {
        final input = <String, dynamic>{
          'id': 'attendance-2',
          'student_id': 'student-1',
          'date': '2026-03-26',
          'start_time': '10:00',
          'end_time': '11:00',
          'status': 'late',
          'price_snapshot': 120.0,
          'fee_amount': 120.0,
          'note': null,
          'lesson_focus_tags': null,
          'home_practice_note': null,
          'progress_scores_json': null,
          'created_at': 1711411200000,
          'updated_at': 1711411200000,
        };

        final model = Attendance.fromMap(input);
        final roundTrip = model.toMap();

        expect(roundTrip.containsKey('lesson_focus_tags'), isTrue);
        expect(roundTrip.containsKey('home_practice_note'), isTrue);
        expect(roundTrip.containsKey('progress_scores_json'), isTrue);
        expect(roundTrip['lesson_focus_tags'], isNull);
        expect(roundTrip['home_practice_note'], isNull);
        expect(roundTrip['progress_scores_json'], isNull);
      },
    );

    test('copyWith can explicitly clear nullable structured fields', () {
      final original = Attendance(
        id: 'attendance-3',
        studentId: 'student-1',
        date: '2026-03-26',
        startTime: '11:00',
        endTime: '12:00',
        status: 'present',
        priceSnapshot: 120,
        feeAmount: 120,
        note: '需要保留',
        lessonFocusTags: <String>['控笔稳定'],
        homePracticeNote: '每日练习',
        progressScores: const AttendanceProgressScores(strokeQuality: 4),
        createdAt: 1711411200000,
        updatedAt: 1711411200000,
      );

      final updated = original.copyWith(
        note: null,
        lessonFocusTags: const <String>[],
        homePracticeNote: null,
        progressScores: null,
      );

      expect(updated.note, isNull);
      expect(updated.lessonFocusTags, isEmpty);
      expect(updated.homePracticeNote, isNull);
      expect(updated.progressScores, isNull);
    });

    test('constructor protects lesson focus tags from external mutation', () {
      final tags = <String>['控笔稳定'];
      final model = Attendance(
        id: 'attendance-4',
        studentId: 'student-1',
        date: '2026-03-27',
        startTime: '09:00',
        endTime: '10:00',
        status: 'present',
        priceSnapshot: 120,
        feeAmount: 120,
        lessonFocusTags: tags,
        createdAt: 1711497600000,
        updatedAt: 1711497600000,
      );

      tags.add('结构观察');

      expect(model.lessonFocusTags, <String>['控笔稳定']);
      expect(() => model.lessonFocusTags.add('追加标签'), throwsUnsupportedError);
    });

    test('codec normalizes tags and tolerates malformed payloads', () {
      expect(
        AttendanceFeedbackCodec.decodeFocusTags('["控笔"," 控笔 ","","结构",1]'),
        <String>['控笔', '结构'],
      );
      expect(AttendanceFeedbackCodec.decodeFocusTags('{not-json'), isEmpty);
      expect(AttendanceFeedbackCodec.decodeProgressScores('{not-json'), isNull);
      expect(AttendanceFeedbackCodec.decodeProgressScores('[]'), isNull);
    });

    test('progress scores copyWith can explicitly clear a score', () {
      const original = AttendanceProgressScores(
        strokeQuality: 4,
        structureAccuracy: 3,
        rhythmConsistency: 5,
      );

      final updated = original.copyWith(
        strokeQuality: null,
        rhythmConsistency: 6,
      );

      expect(updated.strokeQuality, isNull);
      expect(updated.structureAccuracy, 3);
      expect(updated.rhythmConsistency, 6);
    });
  });
}
