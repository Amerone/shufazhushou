import '../../../core/models/attendance.dart';
import '../../../core/models/student.dart';
import '../../../core/models/structured_attendance_feedback.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../shared/constants.dart';

typedef AttendanceIdFactory = String Function();

class QuickEntryInvalidPriceException implements Exception {
  final Student student;

  const QuickEntryInvalidPriceException(this.student);

  @override
  String toString() {
    return '${student.name} 的课时单价无效，请先编辑学生档案。';
  }
}

class QuickEntryRecordRequest {
  final List<Student> students;
  final Map<String, Attendance> conflictRecordsByStudentId;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final List<String> lessonFocusTags;
  final String homePracticeNote;
  final AttendanceProgressScores? progressScores;
  final int nowMs;
  final AttendanceIdFactory idFactory;

  const QuickEntryRecordRequest({
    required this.students,
    required this.conflictRecordsByStudentId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.lessonFocusTags,
    required this.homePracticeNote,
    required this.progressScores,
    required this.nowMs,
    required this.idFactory,
  });
}

class QuickEntryRecordBuildResult {
  final List<Attendance> records;
  final Map<String, String> conflictIds;

  const QuickEntryRecordBuildResult({
    required this.records,
    required this.conflictIds,
  });
}

class QuickEntryRecordBuilder {
  const QuickEntryRecordBuilder();

  QuickEntryRecordBuildResult build({
    required QuickEntryRecordRequest request,
  }) {
    final statusEnum = AttendanceStatus.values.firstWhere(
      (item) => item.name == request.status,
    );
    final conflictIds = {
      for (final entry in request.conflictRecordsByStudentId.entries)
        entry.key: entry.value.id,
    };
    final records = <Attendance>[];

    for (final student in request.students) {
      if (student.pricePerClass < 0) {
        throw QuickEntryInvalidPriceException(student);
      }

      final price = student.pricePerClass;
      final fee = FeeCalculator.calcFee(statusEnum, price);
      final existingRecord = request.conflictRecordsByStudentId[student.id];
      final resolvedLessonFocusTags =
          existingRecord != null && request.lessonFocusTags.isEmpty
          ? existingRecord.lessonFocusTags
          : request.lessonFocusTags;
      final resolvedHomePracticeNote =
          existingRecord != null && request.homePracticeNote.isEmpty
          ? existingRecord.homePracticeNote
          : (request.homePracticeNote.isEmpty
                ? null
                : request.homePracticeNote);
      final resolvedProgressScores =
          existingRecord != null && request.progressScores == null
          ? existingRecord.progressScores
          : request.progressScores;

      records.add(
        existingRecord?.copyWith(
              date: request.date,
              startTime: request.startTime,
              endTime: request.endTime,
              status: request.status,
              priceSnapshot: price,
              feeAmount: fee,
              lessonFocusTags: resolvedLessonFocusTags,
              homePracticeNote: resolvedHomePracticeNote,
              progressScores: resolvedProgressScores,
              updatedAt: request.nowMs,
            ) ??
            Attendance(
              id: request.idFactory(),
              studentId: student.id,
              date: request.date,
              startTime: request.startTime,
              endTime: request.endTime,
              status: request.status,
              priceSnapshot: price,
              feeAmount: fee,
              lessonFocusTags: resolvedLessonFocusTags,
              homePracticeNote: resolvedHomePracticeNote,
              progressScores: resolvedProgressScores,
              createdAt: request.nowMs,
              updatedAt: request.nowMs,
            ),
      );
    }

    return QuickEntryRecordBuildResult(
      records: records,
      conflictIds: conflictIds,
    );
  }
}
