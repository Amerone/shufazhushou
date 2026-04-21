import 'attendance.dart';

class StudentAttendanceInsightFacts {
  final double totalReceivable;
  final String? lastFormalDate;
  final bool hasTrial;
  final bool hasFormal;
  final int? latestUpdatedAt;
  final List<Attendance> recentScoredFormalRecords;

  const StudentAttendanceInsightFacts({
    required this.totalReceivable,
    required this.lastFormalDate,
    required this.hasTrial,
    required this.hasFormal,
    required this.latestUpdatedAt,
    required this.recentScoredFormalRecords,
  });

  static const empty = StudentAttendanceInsightFacts(
    totalReceivable: 0,
    lastFormalDate: null,
    hasTrial: false,
    hasFormal: false,
    latestUpdatedAt: null,
    recentScoredFormalRecords: <Attendance>[],
  );

  factory StudentAttendanceInsightFacts.fromRecords(List<Attendance> records) {
    if (records.isEmpty) {
      return empty;
    }

    var totalReceivable = 0.0;
    String? lastFormalDate;
    var hasTrial = false;
    var hasFormal = false;
    int? latestUpdatedAt;
    final scoredFormalRecords = <Attendance>[];

    for (final record in records) {
      totalReceivable += record.feeAmount;

      if (latestUpdatedAt == null || record.updatedAt > latestUpdatedAt) {
        latestUpdatedAt = record.updatedAt;
      }

      if (record.status == 'trial') {
        hasTrial = true;
      }

      if (!_isFormalStatus(record.status)) {
        continue;
      }

      hasFormal = true;
      if (lastFormalDate == null || record.date.compareTo(lastFormalDate) > 0) {
        lastFormalDate = record.date;
      }

      final progressScores = record.progressScores;
      if (progressScores == null || progressScores.isEmpty) {
        continue;
      }
      scoredFormalRecords.add(record);
    }

    return StudentAttendanceInsightFacts(
      totalReceivable: totalReceivable,
      lastFormalDate: lastFormalDate,
      hasTrial: hasTrial,
      hasFormal: hasFormal,
      latestUpdatedAt: latestUpdatedAt,
      recentScoredFormalRecords: scoredFormalRecords,
    );
  }

  StudentAttendanceInsightFacts copyWith({
    List<Attendance>? recentScoredFormalRecords,
  }) {
    return StudentAttendanceInsightFacts(
      totalReceivable: totalReceivable,
      lastFormalDate: lastFormalDate,
      hasTrial: hasTrial,
      hasFormal: hasFormal,
      latestUpdatedAt: latestUpdatedAt,
      recentScoredFormalRecords:
          recentScoredFormalRecords ?? this.recentScoredFormalRecords,
    );
  }

  static bool _isFormalStatus(String status) {
    return status == 'present' || status == 'late';
  }
}
