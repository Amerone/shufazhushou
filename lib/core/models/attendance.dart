import 'structured_attendance_feedback.dart';

class Attendance {
  static const Object _unset = Object();

  final String id;
  final String studentId;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String status; // present | late | leave | absent | trial
  final double priceSnapshot;
  final double feeAmount;
  final String? note;
  final List<String> lessonFocusTags;
  final String? homePracticeNote;
  final AttendanceProgressScores? progressScores;
  final int createdAt;
  final int updatedAt;

  Attendance({
    required this.id,
    required this.studentId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.priceSnapshot,
    required this.feeAmount,
    this.note,
    List<String> lessonFocusTags = const <String>[],
    this.homePracticeNote,
    this.progressScores,
    required this.createdAt,
    required this.updatedAt,
  }) : lessonFocusTags = List.unmodifiable(lessonFocusTags);

  factory Attendance.fromMap(Map<String, dynamic> m) => Attendance(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        date: m['date'] as String,
        startTime: m['start_time'] as String,
        endTime: m['end_time'] as String,
        status: m['status'] as String,
        priceSnapshot: (m['price_snapshot'] as num).toDouble(),
        feeAmount: (m['fee_amount'] as num).toDouble(),
        note: m['note'] as String?,
        lessonFocusTags:
            AttendanceFeedbackCodec.decodeFocusTags(m['lesson_focus_tags'] as String?),
        homePracticeNote: m['home_practice_note'] as String?,
        progressScores: AttendanceFeedbackCodec.decodeProgressScores(
          m['progress_scores_json'] as String?,
        ),
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'status': status,
        'price_snapshot': priceSnapshot,
        'fee_amount': feeAmount,
        'note': note,
        'lesson_focus_tags': AttendanceFeedbackCodec.encodeFocusTags(lessonFocusTags),
        'home_practice_note': homePracticeNote,
        'progress_scores_json':
            AttendanceFeedbackCodec.encodeProgressScores(progressScores),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Attendance copyWith({
    String? id,
    String? studentId,
    String? date,
    String? startTime,
    String? endTime,
    String? status,
    double? priceSnapshot,
    double? feeAmount,
    Object? note = _unset,
    Object? lessonFocusTags = _unset,
    Object? homePracticeNote = _unset,
    Object? progressScores = _unset,
    int? createdAt,
    int? updatedAt,
  }) =>
      Attendance(
        id: id ?? this.id,
        studentId: studentId ?? this.studentId,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        status: status ?? this.status,
        priceSnapshot: priceSnapshot ?? this.priceSnapshot,
        feeAmount: feeAmount ?? this.feeAmount,
        note: identical(note, _unset) ? this.note : note as String?,
        lessonFocusTags: identical(lessonFocusTags, _unset)
            ? this.lessonFocusTags
            : (lessonFocusTags as List<String>?) ?? const <String>[],
        homePracticeNote: identical(homePracticeNote, _unset)
            ? this.homePracticeNote
            : homePracticeNote as String?,
        progressScores: identical(progressScores, _unset)
            ? this.progressScores
            : progressScores as AttendanceProgressScores?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
