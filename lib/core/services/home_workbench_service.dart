import '../../shared/constants.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import 'insight_aggregation_service.dart';

enum HomeWorkbenchTaskType {
  debt,
  renewal,
  churn,
  trial,
  progress,
  reportReady,
}

class HomeWorkbenchTask {
  final HomeWorkbenchTaskType type;
  final String title;
  final String summary;
  final String actionLabel;
  final String? studentId;
  final String? studentName;

  const HomeWorkbenchTask({
    required this.type,
    required this.title,
    required this.summary,
    required this.actionLabel,
    this.studentId,
    this.studentName,
  });
}

const homeWorkbenchReportReadyDismissType = 'workbench_report_ready';

String homeWorkbenchDismissTypeForTask(HomeWorkbenchTaskType type) {
  switch (type) {
    case HomeWorkbenchTaskType.debt:
      return InsightType.debt.name;
    case HomeWorkbenchTaskType.renewal:
      return InsightType.renewal.name;
    case HomeWorkbenchTaskType.churn:
      return InsightType.churn.name;
    case HomeWorkbenchTaskType.trial:
      return InsightType.trial.name;
    case HomeWorkbenchTaskType.progress:
      return InsightType.progress.name;
    case HomeWorkbenchTaskType.reportReady:
      return homeWorkbenchReportReadyDismissType;
  }
}

String homeWorkbenchDismissKey(String dismissType, String? studentId) {
  return '$dismissType:${studentId ?? ''}';
}

class HomeWorkbenchService {
  const HomeWorkbenchService();

  static const _priority = <HomeWorkbenchTaskType, int>{
    HomeWorkbenchTaskType.debt: 0,
    HomeWorkbenchTaskType.renewal: 1,
    HomeWorkbenchTaskType.churn: 2,
    HomeWorkbenchTaskType.trial: 3,
    HomeWorkbenchTaskType.progress: 4,
    HomeWorkbenchTaskType.reportReady: 5,
  };

  List<HomeWorkbenchTask> buildTasks({
    required List<Insight> insights,
    required List<Student> students,
    required Map<String, String> displayNames,
    required List<Attendance> monthAttendance,
    Set<String> dismissedKeys = const <String>{},
    int maxTasks = 4,
  }) {
    final tasks = <HomeWorkbenchTask>[];
    final occupiedStudentIds = <String>{};

    for (final insight in insights) {
      final task = _taskFromInsight(insight);
      if (task == null) {
        continue;
      }
      tasks.add(task);
      if (task.studentId != null) {
        occupiedStudentIds.add(task.studentId!);
      }
    }

    final reportCandidates = _buildReportReadyTasks(
      students: students,
      displayNames: displayNames,
      monthAttendance: monthAttendance,
      occupiedStudentIds: occupiedStudentIds,
      dismissedKeys: dismissedKeys,
    );
    tasks.addAll(reportCandidates);

    tasks.sort((left, right) {
      final leftPriority = _priority[left.type] ?? 999;
      final rightPriority = _priority[right.type] ?? 999;
      if (leftPriority != rightPriority) {
        return leftPriority.compareTo(rightPriority);
      }
      return left.title.compareTo(right.title);
    });

    return tasks.take(maxTasks).toList(growable: false);
  }

  HomeWorkbenchTask? _taskFromInsight(Insight insight) {
    final studentName = insight.studentName.trim().isEmpty
        ? '当前经营提醒'
        : insight.studentName.trim();

    switch (insight.type) {
      case InsightType.debt:
        return HomeWorkbenchTask(
          type: HomeWorkbenchTaskType.debt,
          title: '$studentName 待核对费用',
          summary: '${insight.message}，${insight.suggestion}',
          actionLabel: '记录缴费',
          studentId: insight.studentId,
          studentName: studentName,
        );
      case InsightType.renewal:
        return HomeWorkbenchTask(
          type: HomeWorkbenchTaskType.renewal,
          title: '$studentName 可沟通续费',
          summary: '${insight.message}，${insight.suggestion}',
          actionLabel: '登记续费',
          studentId: insight.studentId,
          studentName: studentName,
        );
      case InsightType.churn:
        return HomeWorkbenchTask(
          type: HomeWorkbenchTaskType.churn,
          title: '$studentName 需要回访',
          summary: '${insight.message}，${insight.suggestion}',
          actionLabel: '查看档案',
          studentId: insight.studentId,
          studentName: studentName,
        );
      case InsightType.trial:
        return HomeWorkbenchTask(
          type: HomeWorkbenchTaskType.trial,
          title: '$studentName 试听待跟进',
          summary: '${insight.message}，${insight.suggestion}',
          actionLabel: '查看档案',
          studentId: insight.studentId,
          studentName: studentName,
        );
      case InsightType.progress:
        return HomeWorkbenchTask(
          type: HomeWorkbenchTaskType.progress,
          title: '$studentName 适合反馈进步',
          summary: '${insight.message}，${insight.suggestion}',
          actionLabel: '生成月报',
          studentId: insight.studentId,
          studentName: studentName,
        );
      case InsightType.peak:
        return null;
    }
  }

  List<HomeWorkbenchTask> _buildReportReadyTasks({
    required List<Student> students,
    required Map<String, String> displayNames,
    required List<Attendance> monthAttendance,
    required Set<String> occupiedStudentIds,
    required Set<String> dismissedKeys,
  }) {
    final formalCountByStudent = <String, int>{};
    for (final record in monthAttendance) {
      if (record.status != AttendanceStatus.present.name &&
          record.status != AttendanceStatus.late.name) {
        continue;
      }
      formalCountByStudent[record.studentId] =
          (formalCountByStudent[record.studentId] ?? 0) + 1;
    }

    final activeStudents = students.where(
      (student) => student.status == 'active',
    );
    final candidates = <HomeWorkbenchTask>[];

    for (final student in activeStudents) {
      final count = formalCountByStudent[student.id] ?? 0;
      final dismissKey = homeWorkbenchDismissKey(
        homeWorkbenchReportReadyDismissType,
        student.id,
      );
      if (count < 2 ||
          occupiedStudentIds.contains(student.id) ||
          dismissedKeys.contains(dismissKey)) {
        continue;
      }

      candidates.add(
        HomeWorkbenchTask(
          type: HomeWorkbenchTaskType.reportReady,
          title: '${displayNames[student.id] ?? student.name} 可整理月报',
          summary: '本月已完成 $count 节正式课程，适合整理家长版学习快照。',
          actionLabel: '生成月报',
          studentId: student.id,
          studentName: displayNames[student.id] ?? student.name,
        ),
      );
    }

    candidates.sort((left, right) => left.title.compareTo(right.title));
    return candidates;
  }
}
