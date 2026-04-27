import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/utils/fee_calculator.dart';
import 'package:moyun/features/export/services/export_parent_snapshot_service.dart';

void main() {
  test('buildSnapshot exposes balance, progress, attention, and freshness', () {
    final snapshot = const ExportParentSnapshotService().buildSnapshot(
      records: [
        Attendance(
          id: 'a1',
          studentId: 's1',
          date: '2026-04-01',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 180,
          feeAmount: 180,
          lessonFocusTags: ['控笔'],
          homePracticeNote: '每天练习横画',
          createdAt: 1,
          updatedAt: DateTime(2026, 4, 1, 12).millisecondsSinceEpoch,
        ),
      ],
      feeSummary: const StudentFeeSummary(
        totalReceivable: 180,
        totalReceived: 0,
        openingBalance: 0,
        periodNetChange: -180,
        balance: -180,
      ),
      pricePerClass: 180,
    );

    expect(snapshot.balanceLabel, '截至当前待缴 ¥-180.00');
    expect(snapshot.balanceState, LedgerBalanceState.debt);
    expect(snapshot.progressPoint, isNotEmpty);
    expect(snapshot.attentionPoint, isNotEmpty);
    expect(snapshot.dataFreshness, contains('2026-04-01'));
  });
}
