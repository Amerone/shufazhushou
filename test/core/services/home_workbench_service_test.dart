import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/services/home_workbench_service.dart';
import 'package:moyun/core/services/insight_aggregation_service.dart';
import 'package:moyun/shared/constants.dart';

void main() {
  const service = HomeWorkbenchService();

  test('prioritizes urgent insight tasks before report-ready tasks', () {
    final tasks = service.buildTasks(
      insights: const [
        Insight(
          type: InsightType.renewal,
          studentId: 'student-1',
          studentName: 'Alice',
          message: '余额 ¥120.00，约剩 1.2 节',
          suggestion: '建议尽快续费沟通。',
          calcLogic: '',
          dataFreshness: '2026-04-01 09:00',
        ),
      ],
      students: const [
        Student(
          id: 'student-1',
          name: 'Alice',
          parentName: null,
          parentPhone: null,
          pricePerClass: 100,
          status: 'active',
          note: null,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      displayNames: const {'student-1': 'Alice'},
      monthAttendance: [
        Attendance(
          id: 'a-1',
          studentId: 'student-1',
          date: '2026-04-01',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
        Attendance(
          id: 'a-2',
          studentId: 'student-1',
          date: '2026-04-08',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 2,
          updatedAt: 2,
        ),
      ],
    );

    expect(tasks, hasLength(1));
    expect(tasks.first.type, HomeWorkbenchTaskType.renewal);
    expect(tasks.first.actionLabel, '查看续费');
  });

  test('adds report-ready task for active student with two formal classes', () {
    final tasks = service.buildTasks(
      insights: const [],
      students: const [
        Student(
          id: 'student-2',
          name: 'Bella',
          parentName: null,
          parentPhone: null,
          pricePerClass: 100,
          status: 'active',
          note: null,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      displayNames: const {'student-2': 'Bella'},
      monthAttendance: [
        Attendance(
          id: 'b-1',
          studentId: 'student-2',
          date: '2026-04-01',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
        Attendance(
          id: 'b-2',
          studentId: 'student-2',
          date: '2026-04-08',
          startTime: '09:00',
          endTime: '10:00',
          status: 'late',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 2,
          updatedAt: 2,
        ),
      ],
    );

    expect(tasks, hasLength(1));
    expect(tasks.first.type, HomeWorkbenchTaskType.reportReady);
    expect(tasks.first.title, contains('Bella'));
    expect(tasks.first.summary, contains('本月已完成 2 节正式课程'));
  });
}
