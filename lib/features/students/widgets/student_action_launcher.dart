import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/export_template.dart';
import '../../../core/providers/student_provider.dart';
import '../../export/screens/export_config_screen.dart';
import 'payment_bottom_sheet.dart';

Future<void> showStudentPaymentSheet(
  BuildContext context, {
  required String studentId,
  String? studentName,
  double? pricePerClass,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final students = ref.watch(studentProvider).valueOrNull ?? const [];
        final currentStudent = students
            .where((item) => item.student.id == studentId)
            .map((item) => item.student)
            .firstOrNull;

        return PaymentBottomSheet(
          studentId: studentId,
          studentName: studentName ?? currentStudent?.name,
          pricePerClass: pricePerClass ?? currentStudent?.pricePerClass,
        );
      },
    ),
  );
}

Future<void> showStudentExportSheet(
  BuildContext context, {
  required String studentId,
  ExportTemplateId? initialTemplate,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ExportConfigScreen(
      studentId: studentId,
      initialTemplate: initialTemplate,
    ),
  );
}
