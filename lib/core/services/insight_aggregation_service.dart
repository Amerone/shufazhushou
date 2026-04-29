import '../../shared/constants.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/student_insight_facts.dart';
import '../utils/fee_calculator.dart';

class Insight {
  final InsightType type;
  final String? studentId;
  final String studentName;
  final String message;
  final String suggestion;
  final String calcLogic;
  final String dataFreshness;

  const Insight({
    required this.type,
    this.studentId,
    required this.studentName,
    required this.message,
    required this.suggestion,
    required this.calcLogic,
    required this.dataFreshness,
  });
}

class InsightAggregationService {
  const InsightAggregationService();

  static const _progressDimensionLabels = <String, String>{
    'stroke_quality': '笔画质量',
    'structure_accuracy': '结构准确度',
    'rhythm_consistency': '节奏稳定性',
  };

  List<Insight> buildInsights({
    required List<Student> students,
    required Map<String, String> displayNames,
    required Map<String, List<Attendance>> allAttendance,
    required Map<String, double> allPayments,
    required Set<String> dismissedKeys,
    required int activeStudentCount,
    String activePeriodLabel = '\u672C\u5468',
    DateTime? now,
  }) {
    final factsByStudent = <String, StudentAttendanceInsightFacts>{
      for (final entry in allAttendance.entries)
        entry.key: StudentAttendanceInsightFacts.fromRecords(entry.value),
    };

    return buildInsightsFromFacts(
      students: students,
      displayNames: displayNames,
      factsByStudent: factsByStudent,
      allPayments: allPayments,
      dismissedKeys: dismissedKeys,
      activeStudentCount: activeStudentCount,
      activePeriodLabel: activePeriodLabel,
      now: now,
    );
  }

  List<Insight> buildInsightsFromFacts({
    required List<Student> students,
    required Map<String, String> displayNames,
    required Map<String, StudentAttendanceInsightFacts> factsByStudent,
    required Map<String, double> allPayments,
    required Set<String> dismissedKeys,
    required int activeStudentCount,
    String activePeriodLabel = '\u672C\u5468',
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final insights = <Insight>[];

    for (final student in students) {
      final facts =
          factsByStudent[student.id] ?? StudentAttendanceInsightFacts.empty;
      final studentName = displayNames[student.id] ?? student.name;
      final totalReceived = allPayments[student.id] ?? 0;
      final ledger = StudentLedgerView.fromTotals(
        totalReceivable: facts.totalReceivable,
        totalReceived: totalReceived,
        pricePerClass: student.pricePerClass,
      );
      final dataFreshness = _buildDataFreshnessFromFacts(facts, currentTime);

      if (!_isDismissed(dismissedKeys, InsightType.debt, student.id) &&
          ledger.needsPaymentAttention) {
        insights.add(
          Insight(
            type: InsightType.debt,
            studentId: student.id,
            studentName: studentName,
            message: '欠费 ¥${ledger.balance.abs().toStringAsFixed(2)}',
            suggestion: '核对账单，联系家长补缴。',
            calcLogic: '余额小于 0',
            dataFreshness: dataFreshness,
          ),
        );
      }

      if (ledger.needsRenewalAttention &&
          !_isDismissed(dismissedKeys, InsightType.renewal, student.id) &&
          !ledger.needsPaymentAttention) {
        final lessonText = ledger.remainingLessons == null
            ? '剩余课次不可估算'
            : '约剩 ${ledger.remainingLessons!.toStringAsFixed(1)} 节';
        insights.add(
          Insight(
            type: InsightType.renewal,
            studentId: student.id,
            studentName: studentName,
            message: '余额 ¥${ledger.balance.toStringAsFixed(2)}，$lessonText',
            suggestion: '确认续费与下阶段排课。',
            calcLogic:
                '余额 < ¥${kBalanceAlertAmountThreshold.toStringAsFixed(0)} 或课次 < ${kBalanceAlertLessonThreshold.toStringAsFixed(1)}',
            dataFreshness: dataFreshness,
          ),
        );
      }

      if (student.status == 'active' &&
          !_isDismissed(dismissedKeys, InsightType.churn, student.id)) {
        final lastDate = facts.lastFormalDate;
        if (lastDate != null) {
          final inactiveDays = currentTime
              .difference(DateTime.parse(lastDate))
              .inDays;
          if (inactiveDays >= kChurnDays) {
            insights.add(
              Insight(
                type: InsightType.churn,
                studentId: student.id,
                studentName: studentName,
                message: '$inactiveDays 天未出勤',
                suggestion: '回访并安排补课。',
                calcLogic: '超过 $kChurnDays 天未正式出勤',
                dataFreshness: dataFreshness,
              ),
            );
          }
        }
      }

      if (!_isDismissed(dismissedKeys, InsightType.trial, student.id)) {
        if (facts.hasTrial && !facts.hasFormal) {
          insights.add(
            Insight(
              type: InsightType.trial,
              studentId: student.id,
              studentName: studentName,
              message: '已有试听记录，尚未转为正式课程',
              suggestion: '跟进试听反馈。',
              calcLogic: '有试听记录，暂无正式出勤',
              dataFreshness: dataFreshness,
            ),
          );
        }
      }

      if (!_isDismissed(dismissedKeys, InsightType.progress, student.id)) {
        final progressInsight = _buildProgressInsight(
          studentId: student.id,
          studentName: studentName,
          records: facts.recentScoredFormalRecords,
        );
        if (progressInsight != null) {
          insights.add(progressInsight);
        }
      }
    }

    if (!_isDismissed(dismissedKeys, InsightType.peak, null) &&
        activeStudentCount >= kPeakThreshold) {
      insights.add(
        Insight(
          type: InsightType.peak,
          studentName: '',
          message: '$activePeriodLabel活跃学员较多（$activeStudentCount 人）',
          suggestion: '预留补课窗口。',
          calcLogic: '$activePeriodLabel活跃学员达到高峰阈值',
          dataFreshness: _formatTimestamp(currentTime.millisecondsSinceEpoch),
        ),
      );
    }

    return insights;
  }

  Insight? _buildProgressInsight({
    required String studentId,
    required String studentName,
    required List<Attendance> records,
  }) {
    final sortedRecords = [...records]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });

    final snapshots = <_ProgressSnapshot>[];
    for (final record in sortedRecords) {
      if (record.status != 'present' && record.status != 'late') {
        continue;
      }
      final scores = _scoresForRecord(record);
      if (scores.isEmpty) {
        continue;
      }
      snapshots.add(_ProgressSnapshot(record: record, scores: scores));
    }

    if (snapshots.length < 3) {
      return null;
    }

    final recentSnapshots = snapshots.sublist(snapshots.length - 3);
    final improvedDimensions = <String>[];
    for (final entry in _progressDimensionLabels.entries) {
      if (!_isIncreasingAcrossRecentSnapshots(recentSnapshots, entry.key)) {
        continue;
      }
      improvedDimensions.add(entry.value);
    }

    if (improvedDimensions.isEmpty) {
      return null;
    }

    final trendRecord = recentSnapshots.last.record;
    return Insight(
      type: InsightType.progress,
      studentId: studentId,
      studentName: studentName,
      message: '近 3 次评分持续提升：${improvedDimensions.join('、')}',
      suggestion: '生成月报，同步家长。',
      calcLogic: '近 3 次评分连续提升',
      dataFreshness: _formatTimestamp(trendRecord.updatedAt),
    );
  }

  bool _isIncreasingAcrossRecentSnapshots(
    List<_ProgressSnapshot> recentSnapshots,
    String key,
  ) {
    final first = recentSnapshots[0].scores[key];
    final second = recentSnapshots[1].scores[key];
    final third = recentSnapshots[2].scores[key];
    if (first == null || second == null || third == null) {
      return false;
    }
    return first < second && second < third;
  }

  Map<String, double> _scoresForRecord(Attendance record) {
    final progressScores = record.progressScores;
    if (progressScores == null || progressScores.isEmpty) {
      return const <String, double>{};
    }
    return _extractSupportedScores(progressScores.toMap());
  }

  Map<String, double> _extractSupportedScores(Map<String, dynamic> raw) {
    final result = <String, double>{};
    for (final key in _progressDimensionLabels.keys) {
      final value = raw[key];
      if (value is num) {
        result[key] = value.toDouble();
      }
    }
    return result;
  }

  bool _isDismissed(Set<String> dismissedKeys, InsightType type, String? id) {
    return dismissedKeys.contains('${type.name}:${id ?? ''}');
  }

  String _buildDataFreshnessFromFacts(
    StudentAttendanceInsightFacts facts,
    DateTime fallbackNow,
  ) {
    final latest = facts.latestUpdatedAt;
    if (latest == null) {
      return _formatTimestamp(fallbackNow.millisecondsSinceEpoch);
    }
    return _formatTimestamp(latest);
  }

  String _formatTimestamp(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }
}

class _ProgressSnapshot {
  final Attendance record;
  final Map<String, double> scores;

  const _ProgressSnapshot({required this.record, required this.scores});
}
