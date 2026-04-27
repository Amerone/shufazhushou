import '../models/attendance.dart';
import '../models/payment.dart';
import '../utils/fee_calculator.dart';
import 'student_growth_summary_service.dart';

class PdfReportSummary {
  final List<Attendance> sortedRecords;
  final List<Payment> sortedPayments;
  final List<Attendance> feedbackRecords;
  final int totalMinutes;
  final double totalFee;
  final double totalPaid;
  final StudentLedgerView ledger;
  final StudentGrowthSummary growthSummary;

  const PdfReportSummary({
    required this.sortedRecords,
    required this.sortedPayments,
    required this.feedbackRecords,
    required this.totalMinutes,
    required this.totalFee,
    required this.totalPaid,
    required this.ledger,
    required this.growthSummary,
  });
}

class PdfReportSummaryService {
  const PdfReportSummaryService();

  PdfReportSummary build({
    required List<Attendance> records,
    required List<Payment> payments,
    required double pricePerClass,
    required DateTime now,
    StudentFeeSummary? feeSummary,
  }) {
    final sortedRecords = [...records]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.startTime.compareTo(b.startTime);
      });
    final sortedPayments = [...payments]
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    final feedbackRecords = sortedRecords
        .where(_hasStructuredFeedback)
        .toList(growable: false);
    final totalMinutes = sortedRecords.fold<int>(
      0,
      (sum, record) => sum + _durationMinutes(record.startTime, record.endTime),
    );
    final totalFee = sortedRecords.fold<double>(
      0,
      (sum, record) => sum + record.feeAmount,
    );
    final totalPaid = sortedPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final ledger = StudentLedgerView(
      balance: feeSummary?.balance ?? (totalPaid - totalFee),
      pricePerClass: pricePerClass,
      hasBalanceHistory: totalFee > 0 || totalPaid > 0,
    );
    final growthSummary = const StudentGrowthSummaryService().build(
      records: sortedRecords,
      now: now,
    );

    return PdfReportSummary(
      sortedRecords: sortedRecords,
      sortedPayments: sortedPayments,
      feedbackRecords: feedbackRecords,
      totalMinutes: totalMinutes,
      totalFee: totalFee,
      totalPaid: totalPaid,
      ledger: ledger,
      growthSummary: growthSummary,
    );
  }

  bool _hasStructuredFeedback(Attendance record) {
    return record.lessonFocusTags.isNotEmpty ||
        (record.homePracticeNote?.trim().isNotEmpty ?? false) ||
        !(record.progressScores?.isEmpty ?? true);
  }

  int _durationMinutes(String startTime, String endTime) {
    final start = _minutesOfDay(startTime);
    final end = _minutesOfDay(endTime);
    if (start == null || end == null) {
      return 0;
    }
    return end > start ? end - start : 0;
  }

  int? _minutesOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }
}
