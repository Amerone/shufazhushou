import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/providers/attendance_provider.dart';

void main() {
  test(
    'selectedDateAttendanceProvider reads same-month records from month data',
    () async {
      final dao = _FakeAttendanceDao(
        rangeRecords: [
          _attendance(
            id: 'late',
            date: '2026-04-10',
            startTime: '18:00',
            createdAt: 2,
          ),
          _attendance(
            id: 'other-day',
            date: '2026-04-11',
            startTime: '08:00',
            createdAt: 3,
          ),
          _attendance(
            id: 'early',
            date: '2026-04-10',
            startTime: '09:00',
            createdAt: 1,
          ),
        ],
        dateRecords: [_attendance(id: 'dao-fallback', date: '2026-04-10')],
      );
      final container = _container(dao);
      addTearDown(container.dispose);

      container.read(selectedMonthProvider.notifier).state = DateTime(2026, 4);
      container.read(selectedDateProvider.notifier).state = DateTime(
        2026,
        4,
        10,
      );

      final records = await container.read(
        selectedDateAttendanceProvider.future,
      );

      expect(records.map((record) => record.id), ['early', 'late']);
      expect(dao.dateRangeCalls, [('2026-04-01', '2026-04-30')]);
      expect(dao.dateCalls, isEmpty);
    },
  );

  test(
    'selectedDateAttendanceProvider falls back to day DAO off month',
    () async {
      final dao = _FakeAttendanceDao(
        rangeRecords: const [],
        dateRecords: [
          _attendance(
            id: 'late',
            date: '2026-05-10',
            startTime: '18:00',
            createdAt: 2,
          ),
          _attendance(
            id: 'early',
            date: '2026-05-10',
            startTime: '09:00',
            createdAt: 1,
          ),
        ],
      );
      final container = _container(dao);
      addTearDown(container.dispose);

      container.read(selectedMonthProvider.notifier).state = DateTime(2026, 4);
      container.read(selectedDateProvider.notifier).state = DateTime(
        2026,
        5,
        10,
      );

      final records = await container.read(
        selectedDateAttendanceProvider.future,
      );

      expect(records.map((record) => record.id), ['early', 'late']);
      expect(dao.dateRangeCalls, isEmpty);
      expect(dao.dateCalls, ['2026-05-10']);
    },
  );
}

ProviderContainer _container(_FakeAttendanceDao dao) {
  return ProviderContainer(
    overrides: [attendanceDaoProvider.overrideWithValue(dao)],
  );
}

Attendance _attendance({
  required String id,
  required String date,
  String startTime = '09:00',
  int createdAt = 1,
}) {
  return Attendance(
    id: id,
    studentId: 'student-1',
    date: date,
    startTime: startTime,
    endTime: '10:00',
    status: 'present',
    priceSnapshot: 100,
    feeAmount: 100,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

class _FakeAttendanceDao extends AttendanceDao {
  final List<Attendance> rangeRecords;
  final List<Attendance> dateRecords;
  final List<(String, String)> dateRangeCalls = [];
  final List<String> dateCalls = [];

  _FakeAttendanceDao({required this.rangeRecords, required this.dateRecords})
    : super(DatabaseHelper.instance);

  @override
  Future<List<Attendance>> getByDateRange(String from, String to) async {
    dateRangeCalls.add((from, to));
    return List<Attendance>.from(rangeRecords);
  }

  @override
  Future<List<Attendance>> getByDate(String date) async {
    dateCalls.add(date);
    return List<Attendance>.from(dateRecords);
  }
}
