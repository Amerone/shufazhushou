import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/features/students/widgets/student_picker_sheet.dart';
import 'package:moyun/shared/theme.dart';

void main() {
  testWidgets('student picker surfaces recent attendance students first', (
    tester,
  ) async {
    _FakeStudentNotifier.seededStudents = [
      StudentWithMeta(
        const Student(
          id: 'student-1',
          name: '最近上课',
          parentName: '家长A',
          parentPhone: '13900000001',
          pricePerClass: 180,
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
        ),
        '2026-04-01',
      ),
      StudentWithMeta(
        const Student(
          id: 'student-2',
          name: '未记课',
          parentName: '家长B',
          parentPhone: '13900000002',
          pricePerClass: 180,
          status: 'active',
          createdAt: 2,
          updatedAt: 2,
        ),
        null,
      ),
      StudentWithMeta(
        const Student(
          id: 'student-3',
          name: '较早上课',
          parentName: '家长C',
          parentPhone: '13900000003',
          pricePerClass: 180,
          status: 'active',
          createdAt: 3,
          updatedAt: 3,
        ),
        '2026-03-20',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [studentProvider.overrideWith(_FakeStudentNotifier.new)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: StudentPickerSheet(
              title: '选择学生',
              subtitle: '用于记录缴费',
              actionLabel: '记录缴费',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('已按最近上课排序，今天刚上课或最近常上的学生会排在前面。'), findsOneWidget);
    expect(find.text('最近上课 2026-04-01'), findsOneWidget);
    expect(find.text('未记过课'), findsOneWidget);

    final recentTop = tester.getTopLeft(find.text('最近上课')).dy;
    final olderTop = tester.getTopLeft(find.text('较早上课')).dy;
    final neverTop = tester.getTopLeft(find.text('未记课')).dy;

    expect(recentTop, lessThan(olderTop));
    expect(olderTop, lessThan(neverTop));
  });
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;
}
