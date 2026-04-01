import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/students/screens/student_form_screen.dart';

void main() {
  testWidgets('edit form populates after student provider finishes loading', (
    tester,
  ) async {
    final completer = Completer<List<StudentWithMeta>>();
    _DelayedStudentNotifier.pendingResult = completer;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [studentProvider.overrideWith(_DelayedStudentNotifier.new)],
        child: const MaterialApp(
          home: StudentFormScreen(studentId: 'student-1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('Parent A'), findsNothing);

    completer.complete([
      StudentWithMeta(
        const Student(
          id: 'student-1',
          name: 'Alice',
          parentName: 'Parent A',
          parentPhone: '13900000001',
          pricePerClass: 180,
          status: 'active',
          note: 'Prefers weekend classes',
          createdAt: 1,
          updatedAt: 1,
        ),
        '2026-03-30',
      ),
    ]);

    await tester.pump();
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Parent A'), findsOneWidget);
    expect(find.text('13900000001'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
    expect(find.text('Prefers weekend classes'), findsOneWidget);
  });
}

class _DelayedStudentNotifier extends StudentNotifier {
  static Completer<List<StudentWithMeta>>? pendingResult;

  @override
  Future<List<StudentWithMeta>> build() async {
    return pendingResult!.future;
  }
}
