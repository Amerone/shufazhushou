import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/student.dart';
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
    builder: (_) {
      if (studentName != null && pricePerClass != null) {
        return PaymentBottomSheet(
          studentId: studentId,
          studentName: studentName,
          pricePerClass: pricePerClass,
        );
      }

      return Consumer(
        builder: (context, ref, _) {
          final students = ref.watch(studentProvider).valueOrNull ?? const [];
          Student? currentStudent;
          for (final item in students) {
            if (item.student.id == studentId) {
              currentStudent = item.student;
              break;
            }
          }

          return PaymentBottomSheet(
            studentId: studentId,
            studentName: studentName ?? currentStudent?.name,
            pricePerClass: pricePerClass ?? currentStudent?.pricePerClass,
          );
        },
      );
    },
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
