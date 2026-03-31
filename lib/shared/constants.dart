import 'package:flutter/material.dart';
import 'theme.dart';

enum AttendanceStatus { present, late, leave, absent, trial }

const kStatusLabel = <AttendanceStatus, String>{
  AttendanceStatus.present: '\u51fa\u52e4',
  AttendanceStatus.late: '\u8fdf\u5230',
  AttendanceStatus.leave: '\u8bf7\u5047',
  AttendanceStatus.absent: '\u7f3a\u52e4',
  AttendanceStatus.trial: '\u8bd5\u542c',
};

const kStatusColor = <AttendanceStatus, Color>{
  AttendanceStatus.present: kGreen,
  AttendanceStatus.late: kOrange,
  AttendanceStatus.leave: kInkSecondary,
  AttendanceStatus.absent: kRed,
  AttendanceStatus.trial: kSealRed,
};

/// Lookup status label by string key (for model fields stored as String).
String statusLabel(String status) {
  final e = AttendanceStatus.values.asNameMap()[status];
  return e != null ? kStatusLabel[e]! : status;
}

/// Lookup status color by string key (for model fields stored as String).
Color statusColor(String status) {
  final e = AttendanceStatus.values.asNameMap()[status];
  return e != null ? kStatusColor[e]! : kInkSecondary;
}

enum InsightType { debt, renewal, churn, peak, trial, progress }

const kPeakThreshold = 3;
const kChurnDays = 21;
const kBackupWarningDays = 7;
const kBalanceAlertAmountThreshold = 300.0;
const kBalanceAlertLessonThreshold = 3.0;

const kDefaultTeacherName = '\u58a8\u97f5\u6559\u5e08';
const kDefaultInstitutionName = '\u58a8\u97f5';
const kDefaultInstitutionMotto =
    '\u4e13\u6ce8\u843d\u7b14\uff0c\u4ece\u5bb9\u4e60\u5b57';
const kDefaultSealText = 'MOYU';
const kDefaultSealFont = 'xiaozhuan';
const kDefaultSealLayout = 'grid';
const kDefaultSealBorder = 'full';

/// Format a DateTime as 'YYYY-MM-DD' string for storage/comparison.
String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Parse "HH:mm" string to TimeOfDay.
TimeOfDay parseTime(String time) {
  final parts = time.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// Format TimeOfDay as "HH:mm" string.
String formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// Attendance rate = (present + late) / (present + late + absent) * 100%
