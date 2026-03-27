import 'package:calligraphy_assistant/core/models/attendance.dart';
import 'package:calligraphy_assistant/core/models/structured_attendance_feedback.dart';
import 'package:calligraphy_assistant/core/models/student.dart';
import 'package:calligraphy_assistant/core/services/insight_aggregation_service.dart';
import 'package:calligraphy_assistant/shared/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = InsightAggregationService();

  group('InsightAggregationService', () {
    test('creates renewal insight when balance falls below thresholds', () {
      final students = [
        const Student(
          id: 'student-1',
          name: '张三',
          parentName: '李女士',
          parentPhone: '13800000000',
          pricePerClass: 100,
          status: 'active',
          note: null,
          createdAt: 1,
          updatedAt: 1,
        ),
      ];

      final records = {
        'student-1': [
          Attendance(
            id: 'a-1',
            studentId: 'student-1',
            date: '2026-03-20',
            startTime: '09:00',
            endTime: '10:00',
            status: 'present',
            priceSnapshot: 100,
            feeAmount: 100,
            createdAt: 10,
            updatedAt: 10,
          ),
        ],
      };

      final insights = service.buildInsights(
        students: students,
        displayNames: const {'student-1': '张三'},
        allAttendance: records,
        allPayments: const {'student-1': 250},
        dismissedKeys: const <String>{},
        weeklyActiveStudentCount: 0,
        now: DateTime(2026, 3, 27, 9, 0),
      );

      final renewal = insights.firstWhere(
        (item) => item.type == InsightType.renewal,
      );

      expect(renewal.studentId, 'student-1');
      expect(renewal.message, contains('余额'));
      expect(renewal.calcLogic, contains('余额小于'));
    });

    test('creates progress insight after three consecutive improvements', () {
      final students = [
        const Student(
          id: 'student-2',
          name: '李四',
          parentName: null,
          parentPhone: null,
          pricePerClass: 120,
          status: 'active',
          note: null,
          createdAt: 1,
          updatedAt: 1,
        ),
      ];

      final records = {
        'student-2': [
          Attendance(
            id: 'p-1',
            studentId: 'student-2',
            date: '2026-03-01',
            startTime: '09:00',
            endTime: '10:00',
            status: 'present',
            priceSnapshot: 120,
            feeAmount: 120,
            progressScores: AttendanceProgressScores(
              strokeQuality: 2,
              structureAccuracy: 2,
            ),
            createdAt: 10,
            updatedAt: 10,
          ),
          Attendance(
            id: 'p-2',
            studentId: 'student-2',
            date: '2026-03-08',
            startTime: '09:00',
            endTime: '10:00',
            status: 'present',
            priceSnapshot: 120,
            feeAmount: 120,
            progressScores: AttendanceProgressScores(
              strokeQuality: 3,
              structureAccuracy: 3,
            ),
            createdAt: 20,
            updatedAt: 20,
          ),
          Attendance(
            id: 'p-3',
            studentId: 'student-2',
            date: '2026-03-15',
            startTime: '09:00',
            endTime: '10:00',
            status: 'present',
            priceSnapshot: 120,
            feeAmount: 120,
            progressScores: AttendanceProgressScores(
              strokeQuality: 4,
              structureAccuracy: 4,
            ),
            createdAt: 30,
            updatedAt: 30,
          ),
        ],
      };

      final insights = service.buildInsights(
        students: students,
        displayNames: const {'student-2': '李四'},
        allAttendance: records,
        allPayments: const {'student-2': 600},
        dismissedKeys: const <String>{},
        weeklyActiveStudentCount: 0,
        now: DateTime(2026, 3, 27, 9, 0),
      );

      final progress = insights.firstWhere(
        (item) => item.type == InsightType.progress,
      );

      expect(progress.studentId, 'student-2');
      expect(progress.message, contains('近 3 次评分持续提升'));
      expect(progress.suggestion, contains('成长快照'));
    });

    test('uses only the latest three scoring records for progress insight', () {
      final students = [
        const Student(
          id: 'student-4',
          name: '赵六',
          parentName: null,
          parentPhone: null,
          pricePerClass: 120,
          status: 'active',
          note: null,
          createdAt: 1,
          updatedAt: 1,
        ),
      ];

      final records = {
        'student-4': [
          Attendance(
            id: 'l-1',
            studentId: 'student-4',
            date: '2026-03-01',
            startTime: '09:00',
            endTime: '10:00',
            status: 'present',
            priceSnapshot: 120,
            feeAmount: 120,
            progressScores: AttendanceProgressScores(strokeQuality: 2),
            createdAt: 10,
            updatedAt: 10,
          ),
          Attendance(
            id: 'l-2',
            studentId: 'student-4',
            date: '2026-03-08',
            startTime: '09:00',
            endTime: '10:00',
            status: 'present',
            priceSnapshot: 120,
            feeAmount: 120,
            progressScores: AttendanceProgressScores(strokeQuality: 3),
            createdAt: 20,
            updatedAt: 20,
          ),
          Attendance(
            id: 'l-3',
            studentId: 'student-4',
            date: '2026-03-15',
            startTime: '09:00',
            endTime: '10:00',
            status: 'present',
            priceSnapshot: 120,
            feeAmount: 120,
            progressScores: AttendanceProgressScores(strokeQuality: 4),
            createdAt: 30,
            updatedAt: 30,
          ),
          Attendance(
            id: 'l-4',
            studentId: 'student-4',
            date: '2026-03-22',
            startTime: '09:00',
            endTime: '10:00',
            status: 'present',
            priceSnapshot: 120,
            feeAmount: 120,
            progressScores: AttendanceProgressScores(strokeQuality: 3),
            createdAt: 40,
            updatedAt: 40,
          ),
        ],
      };

      final insights = service.buildInsights(
        students: students,
        displayNames: const {'student-4': '赵六'},
        allAttendance: records,
        allPayments: const {'student-4': 600},
        dismissedKeys: const <String>{},
        weeklyActiveStudentCount: 0,
        now: DateTime(2026, 3, 27, 9, 0),
      );

      expect(
        insights.where((item) => item.type == InsightType.progress),
        isEmpty,
      );
    });

    test('does not create renewal insight for student without balance history', () {
      final students = [
        const Student(
          id: 'student-3',
          name: '王五',
          parentName: null,
          parentPhone: null,
          pricePerClass: 100,
          status: 'active',
          note: null,
          createdAt: 1,
          updatedAt: 1,
        ),
      ];

      final insights = service.buildInsights(
        students: students,
        displayNames: const {'student-3': '王五'},
        allAttendance: const {'student-3': <Attendance>[]},
        allPayments: const {'student-3': 0},
        dismissedKeys: const <String>{},
        weeklyActiveStudentCount: 0,
        now: DateTime(2026, 3, 27, 9, 0),
      );

      expect(
        insights.where((item) => item.type == InsightType.renewal),
        isEmpty,
      );
    });
  });
}
