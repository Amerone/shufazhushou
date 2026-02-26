import 'package:flutter/material.dart';
import 'theme.dart';

enum AttendanceStatus { present, late, leave, absent, trial }

const kStatusLabel = {
  'present': '出勤',
  'late': '迟到',
  'leave': '请假',
  'absent': '缺勤',
  'trial': '试听',
};

const kStatusColor = <String, Color>{
  'present': kGreen,
  'late': kOrange,
  'leave': kInkSecondary,
  'absent': kRed,
  'trial': kSealRed,
};

enum InsightType { debt, churn, peak, trial }

const kPeakThreshold = 3;
const kChurnDays = 21;
const kBackupWarningDays = 7;

const kDefaultTeacherName = '梁老师';
const kDefaultSealText = '梁围围书';
const kDefaultSealFont = 'xiaozhuan';
const kDefaultSealLayout = 'grid';
const kDefaultSealBorder = 'full';

/// Format a DateTime as 'YYYY-MM-DD' string for storage/comparison.
String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// 出勤率 = (present + late) / (present + late + absent) × 100%
