import 'package:flutter/material.dart';
import 'theme.dart';

enum AttendanceStatus { present, late, leave, absent, trial }

const kStatusLabel = <AttendanceStatus, String>{
  AttendanceStatus.present: '出勤',
  AttendanceStatus.late: '迟到',
  AttendanceStatus.leave: '请假',
  AttendanceStatus.absent: '缺勤',
  AttendanceStatus.trial: '试听',
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

const kDefaultTeacherName = '梁老师';
const kDefaultInstitutionName = '院城墨点';
const kDefaultInstitutionMotto = '执笔有境  观心成章';
const kDefaultSealText = '梁围围书';
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

// 出勤率 = (present + late) / (present + late + absent) × 100%
