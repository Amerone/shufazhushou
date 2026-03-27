import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'attendance_provider.dart';
import 'class_template_provider.dart';
import 'contribution_provider.dart';
import 'fee_summary_provider.dart';
import 'heatmap_provider.dart';
import 'insight_provider.dart';
import 'metrics_provider.dart';
import 'revenue_provider.dart';
import 'settings_provider.dart';
import 'status_distribution_provider.dart';
import 'student_provider.dart';

/// Invalidate providers after attendance records are created, updated, or deleted.
void invalidateAfterAttendanceChange(WidgetRef ref) {
  ref.invalidate(studentProvider);
  ref.invalidate(attendanceProvider);
  ref.invalidate(feeSummaryProvider);
  ref.invalidate(metricsProvider);
  ref.invalidate(revenueProvider);
  ref.invalidate(contributionProvider);
  ref.invalidate(statusDistributionProvider);
  ref.invalidate(heatmapProvider);
  ref.invalidate(insightProvider);
}

/// Invalidate providers after a payment is created or deleted.
void invalidateAfterPaymentChange(WidgetRef ref) {
  ref.invalidate(feeSummaryProvider);
  ref.invalidate(revenueProvider);
  ref.invalidate(insightProvider);
}

/// Invalidate providers after a student is deleted (cascade deletes attendance/payments).
void invalidateAfterStudentDelete(WidgetRef ref) {
  ref.invalidate(studentProvider);
  ref.invalidate(attendanceProvider);
  ref.invalidate(feeSummaryProvider);
  ref.invalidate(metricsProvider);
  ref.invalidate(revenueProvider);
  ref.invalidate(contributionProvider);
  ref.invalidate(statusDistributionProvider);
  ref.invalidate(heatmapProvider);
  ref.invalidate(insightProvider);
}

/// Invalidate all statistics-related providers (for refresh on statistics page).
void invalidateStatistics(WidgetRef ref) {
  ref.invalidate(attendanceProvider);
  ref.invalidate(metricsProvider);
  ref.invalidate(revenueProvider);
  ref.invalidate(contributionProvider);
  ref.invalidate(statusDistributionProvider);
  ref.invalidate(heatmapProvider);
  ref.invalidate(insightProvider);
}

/// Invalidate all data providers (for seed data / clear all data).
void invalidateAll(WidgetRef ref) {
  ref.invalidate(studentProvider);
  ref.invalidate(attendanceProvider);
  ref.invalidate(feeSummaryProvider);
  ref.invalidate(metricsProvider);
  ref.invalidate(revenueProvider);
  ref.invalidate(contributionProvider);
  ref.invalidate(statusDistributionProvider);
  ref.invalidate(heatmapProvider);
  ref.invalidate(insightProvider);
  ref.invalidate(settingsProvider);
  ref.invalidate(classTemplateProvider);
}
