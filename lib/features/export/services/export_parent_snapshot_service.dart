import '../../../core/models/attendance.dart';
import '../../../core/services/student_growth_summary_service.dart';
import '../../../core/utils/fee_calculator.dart';

class ExportParentSnapshot {
  final String balanceLabel;
  final LedgerBalanceState balanceState;
  final String nextLessonLabel;
  final String progressPoint;
  final String attentionPoint;
  final String dataFreshness;

  const ExportParentSnapshot({
    required this.balanceLabel,
    required this.balanceState,
    required this.nextLessonLabel,
    required this.progressPoint,
    required this.attentionPoint,
    required this.dataFreshness,
  });
}

class ExportParentSnapshotService {
  const ExportParentSnapshotService();

  ExportParentSnapshot buildSnapshot({
    required List<Attendance> records,
    required StudentFeeSummary feeSummary,
    required double pricePerClass,
  }) {
    final summary = const StudentGrowthSummaryService().build(records: records);
    final ledger = StudentLedgerView.fromSummary(
      feeSummary,
      pricePerClass: pricePerClass,
    );

    return ExportParentSnapshot(
      balanceLabel:
          '${ledger.currentBalanceLabel} ¥${feeSummary.balance.toStringAsFixed(2)}',
      balanceState: ledger.balanceState,
      nextLessonLabel: summary.nextLessonLabel,
      progressPoint: summary.progressPoint,
      attentionPoint: summary.attentionPoint,
      dataFreshness: summary.dataFreshness,
    );
  }
}
