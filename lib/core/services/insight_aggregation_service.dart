import '../../shared/constants.dart';
import '../models/attendance.dart';
import '../models/student.dart';

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
    'structure_accuracy': '结构准确',
    'rhythm_consistency': '节奏连贯',
  };

  List<Insight> buildInsights({
    required List<Student> students,
    required Map<String, String> displayNames,
    required Map<String, List<Attendance>> allAttendance,
    required Map<String, double> allPayments,
    required Set<String> dismissedKeys,
    required int weeklyActiveStudentCount,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final insights = <Insight>[];

    for (final student in students) {
      final records = allAttendance[student.id] ?? const <Attendance>[];
      final studentName = displayNames[student.id] ?? student.name;
      final totalReceived = allPayments[student.id] ?? 0;
      final totalReceivable =
          records.fold<double>(0, (sum, item) => sum + item.feeAmount);
      final balance = totalReceived - totalReceivable;
      final hasBalanceContext = totalReceived > 0 || totalReceivable > 0;
      final dataFreshness = _buildDataFreshness(records, currentTime);

      if (!_isDismissed(dismissedKeys, InsightType.debt, student.id) &&
          balance < 0) {
        insights.add(
          Insight(
            type: InsightType.debt,
            studentId: student.id,
            studentName: studentName,
            message: '欠费 ¥${(-balance).toStringAsFixed(2)}',
            suggestion: '建议优先核对账单，并尽快联系家长确认补缴或续费安排。',
            calcLogic: '累计余额 = 累计已收 - 累计应收；当余额小于 0 时触发欠费提醒。',
            dataFreshness: dataFreshness,
          ),
        );
      }

      final remainingLessons = student.pricePerClass > 0
          ? balance / student.pricePerClass
          : null;
      final hitAmountThreshold =
          balance >= 0 && balance < kBalanceAlertAmountThreshold;
      final hitLessonThreshold = remainingLessons != null &&
          remainingLessons >= 0 &&
          remainingLessons < kBalanceAlertLessonThreshold;

      if (hasBalanceContext &&
          !_isDismissed(dismissedKeys, InsightType.renewal, student.id) &&
          (hitAmountThreshold || hitLessonThreshold)) {
        final lessonText = remainingLessons == null
            ? '剩余课次不可估算'
            : '约剩 ${remainingLessons.toStringAsFixed(1)} 节';
        insights.add(
          Insight(
            type: InsightType.renewal,
            studentId: student.id,
            studentName: studentName,
            message: '余额 ¥${balance.toStringAsFixed(2)}，$lessonText',
            suggestion: '建议本周内发起续费沟通，并同步下一阶段课程安排建议。',
            calcLogic:
                '当余额小于 ¥${kBalanceAlertAmountThreshold.toStringAsFixed(0)} 或剩余课次少于 ${kBalanceAlertLessonThreshold.toStringAsFixed(1)} 节时触发。',
            dataFreshness: dataFreshness,
          ),
        );
      }

      if (student.status == 'active' &&
          !_isDismissed(dismissedKeys, InsightType.churn, student.id)) {
        final formalDates = records
            .where((item) => item.status == 'present' || item.status == 'late')
            .map((item) => item.date);
        if (formalDates.isNotEmpty) {
          final lastDate =
              formalDates.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
          final inactiveDays =
              currentTime.difference(DateTime.parse(lastDate)).inDays;
          if (inactiveDays >= kChurnDays) {
            insights.add(
              Insight(
                type: InsightType.churn,
                studentId: student.id,
                studentName: studentName,
                message: '$inactiveDays 天未出勤',
                suggestion: '建议尽快回访，确认近期学习节奏并安排补课或复习。',
                calcLogic: '最近一次正式出勤距离当前超过 $kChurnDays 天时触发流失预警。',
                dataFreshness: dataFreshness,
              ),
            );
          }
        }
      }

      if (!_isDismissed(dismissedKeys, InsightType.trial, student.id)) {
        final hasTrial = records.any((item) => item.status == 'trial');
        final hasFormal = records
            .any((item) => item.status == 'present' || item.status == 'late');
        if (hasTrial && !hasFormal) {
          insights.add(
            Insight(
              type: InsightType.trial,
              studentId: student.id,
              studentName: studentName,
              message: '已有试听记录，尚未转为正式课程',
              suggestion: '建议在 7 天内完成试听复盘，并给出首月课包建议。',
              calcLogic: '存在试听记录且暂无正式出勤记录时触发试听转化提醒。',
              dataFreshness: dataFreshness,
            ),
          );
        }
      }

      if (!_isDismissed(dismissedKeys, InsightType.progress, student.id)) {
        final progressInsight = _buildProgressInsight(
          studentId: student.id,
          studentName: studentName,
          records: records,
        );
        if (progressInsight != null) {
          insights.add(progressInsight);
        }
      }
    }

    if (!_isDismissed(dismissedKeys, InsightType.peak, null) &&
        weeklyActiveStudentCount >= kPeakThreshold) {
      insights.add(
        Insight(
          type: InsightType.peak,
          studentName: '',
          message: '本周活跃学员较多（$weeklyActiveStudentCount 人）',
          suggestion: '建议提前预留高峰时段补课窗口，并确认本周排课余量。',
          calcLogic: '本周活跃学员数达到高峰阈值时触发提示。',
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
      suggestion: '建议生成成长快照并同步家长，延续当前训练节奏。',
      calcLogic: '在最近 3 次有效评分记录中，至少一个维度连续递增时触发。',
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

  String _buildDataFreshness(List<Attendance> records, DateTime fallbackNow) {
    if (records.isEmpty) {
      return _formatTimestamp(fallbackNow.millisecondsSinceEpoch);
    }
    var latest = records.first.updatedAt;
    for (final record in records.skip(1)) {
      if (record.updatedAt > latest) {
        latest = record.updatedAt;
      }
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

  const _ProgressSnapshot({
    required this.record,
    required this.scores,
  });
}
