import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';
import 'package:moyun/features/home/services/quick_entry_record_builder.dart';

void main() {
  test('build preserves existing feedback and artwork during overwrite', () {
    final existing = Attendance(
      id: 'attendance-old',
      studentId: 'student-1',
      date: '2026-04-17',
      startTime: '18:00',
      endTime: '19:30',
      status: 'present',
      priceSnapshot: 180,
      feeAmount: 180,
      note: 'manual note',
      lessonFocusTags: const ['章法布局'],
      homePracticeNote: 'old practice',
      progressScores: const AttendanceProgressScores(strokeQuality: 4),
      artworkImagePath: 'artworks/old.png',
      createdAt: 11,
      updatedAt: 22,
    );

    final result = const QuickEntryRecordBuilder().build(
      request: QuickEntryRecordRequest(
        students: [
          const Student(
            id: 'student-1',
            name: 'Alice',
            pricePerClass: 180,
            status: 'active',
            createdAt: 1,
            updatedAt: 1,
          ),
        ],
        conflictRecordsByStudentId: {'student-1': existing},
        date: '2026-04-18',
        startTime: '19:00',
        endTime: '20:00',
        status: 'late',
        lessonFocusTags: [],
        homePracticeNote: '',
        progressScores: null,
        nowMs: 99,
        idFactory: _FixedIdFactory('new-id').next,
      ),
    );

    expect(result.conflictIds, {'student-1': 'attendance-old'});
    expect(result.records, hasLength(1));
    final saved = result.records.single;
    expect(saved.id, 'attendance-old');
    expect(saved.note, 'manual note');
    expect(saved.lessonFocusTags, const ['章法布局']);
    expect(saved.homePracticeNote, 'old practice');
    expect(saved.progressScores?.strokeQuality, 4);
    expect(saved.artworkImagePath, 'artworks/old.png');
    expect(saved.createdAt, 11);
    expect(saved.updatedAt, 99);
    expect(saved.date, '2026-04-18');
    expect(saved.startTime, '19:00');
    expect(saved.endTime, '20:00');
    expect(saved.status, 'late');
    expect(saved.feeAmount, 180);
  });

  test('build rejects negative student price', () {
    expect(
      () => const QuickEntryRecordBuilder().build(
        request: QuickEntryRecordRequest(
          students: [
            const Student(
              id: 'student-1',
              name: 'Alice',
              pricePerClass: -1,
              status: 'active',
              createdAt: 1,
              updatedAt: 1,
            ),
          ],
          conflictRecordsByStudentId: const {},
          date: '2026-04-18',
          startTime: '19:00',
          endTime: '20:00',
          status: 'present',
          lessonFocusTags: const [],
          homePracticeNote: '',
          progressScores: null,
          nowMs: 99,
          idFactory: _FixedIdFactory('new-id').next,
        ),
      ),
      throwsA(isA<QuickEntryInvalidPriceException>()),
    );
  });
}

class _FixedIdFactory {
  final String id;

  const _FixedIdFactory(this.id);

  String next() => id;
}
