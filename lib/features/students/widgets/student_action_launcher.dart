import 'package:flutter/material.dart';

import '../../../core/models/export_template.dart';
import '../../export/screens/export_config_screen.dart';
import 'payment_bottom_sheet.dart';

Future<void> showStudentPaymentSheet(
  BuildContext context, {
  required String studentId,
  String? studentName,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        PaymentBottomSheet(studentId: studentId, studentName: studentName),
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
