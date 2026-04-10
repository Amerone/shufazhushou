import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/widgets/attendance_edit_sheet.dart';

void main() {
  testWidgets('attendance edit sheet shows live fee preview for status', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final record = Attendance(
      id: 'attendance-1',
      studentId: 'student-1',
      date: '2026-04-03',
      startTime: '09:00',
      endTime: '10:00',
      status: 'present',
      priceSnapshot: 180,
      feeAmount: 180,
      createdAt: 1,
      updatedAt: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: AttendanceEditSheet(record: record)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('课时单价 ¥180'), findsOneWidget);
    expect(find.text('本次扣费 ¥180'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '请假'));
    await tester.pumpAndSettle();

    expect(find.text('本次扣费 ¥0'), findsOneWidget);
  });

  testWidgets('attendance edit sheet exposes artwork analysis action', (
    tester,
  ) async {
    _setLargeViewport(tester);
    var analyzed = false;
    final record = Attendance(
      id: 'attendance-1',
      studentId: 'student-1',
      date: '2026-04-03',
      startTime: '09:00',
      endTime: '10:00',
      status: 'present',
      priceSnapshot: 180,
      feeAmount: 180,
      createdAt: 1,
      updatedAt: 1,
    );
    final fakeDao = _FakeAttendanceDao({record.id: record});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [attendanceDaoProvider.overrideWithValue(fakeDao)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: AttendanceEditSheet(
              record: record,
              onAnalyzeArtwork: () async {
                analyzed = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 作品分析'), findsOneWidget);
    expect(find.text('拍照 / 选照片分析'), findsOneWidget);

    await tester.tap(find.text('拍照 / 选照片分析'));
    await tester.pumpAndSettle();

    expect(analyzed, isTrue);
  });

  testWidgets('attendance edit sheet keeps AI analysis changes on save', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final initialRecord = Attendance(
      id: 'attendance-1',
      studentId: 'student-1',
      date: '2026-04-03',
      startTime: '09:00',
      endTime: '10:00',
      status: 'present',
      priceSnapshot: 180,
      feeAmount: 180,
      createdAt: 1,
      updatedAt: 1,
    );
    final fakeDao = _FakeAttendanceDao({initialRecord.id: initialRecord});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [attendanceDaoProvider.overrideWithValue(fakeDao)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: AttendanceEditSheet(
              record: initialRecord,
              onAnalyzeArtwork: () async {
                await fakeDao.update(
                  initialRecord.copyWith(
                    homePracticeNote: 'AI 练习建议',
                    artworkImagePath: 'artworks/attendance-1.png',
                    updatedAt: 2,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    final savedRecord = fakeDao.records[initialRecord.id];
    expect(savedRecord, isNotNull);
    expect(savedRecord!.homePracticeNote, 'AI 练习建议');
    expect(savedRecord.artworkImagePath, 'artworks/attendance-1.png');
  });
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _FakeAttendanceDao extends AttendanceDao {
  final Map<String, Attendance> records;

  _FakeAttendanceDao(this.records) : super(DatabaseHelper.instance);

  @override
  Future<void> delete(String id) async {
    records.remove(id);
  }

  @override
  Future<Attendance?> findConflict(
    String studentId,
    String date,
    String startTime,
    String endTime, {
    String? excludeId,
  }) async {
    return null;
  }

  @override
  Future<Attendance?> getById(String id) async {
    return records[id];
  }

  @override
  Future<void> update(Attendance r) async {
    records[r.id] = r;
  }
}
