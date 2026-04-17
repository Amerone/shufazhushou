import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/student_provider.dart';

void main() {
  test('studentRosterSummaryProvider exposes count and ids', () async {
    final container = ProviderContainer(
      overrides: [
        studentDaoProvider.overrideWithValue(
          _FakeStudentDao([
            StudentWithMeta(_student('student-b'), null),
            StudentWithMeta(_student('student-a'), '2026-04-01'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(studentProvider.future);

    final summary = container.read(studentRosterSummaryProvider);

    expect(summary.count, 2);
    expect(summary.hasStudents, isTrue);
    expect(summary.ids, containsAll(['student-a', 'student-b']));
  });

  test('StudentRosterSummary equality is independent of student order', () {
    final first = StudentRosterSummary.fromStudents([
      StudentWithMeta(_student('student-b'), null),
      StudentWithMeta(_student('student-a'), null),
    ]);
    final second = StudentRosterSummary.fromStudents([
      StudentWithMeta(_student('student-a'), null),
      StudentWithMeta(_student('student-b'), null),
    ]);

    expect(first, second);
  });

  test(
    'studentDisplayNameMapProvider reuses student data for duplicate names',
    () async {
      final container = ProviderContainer(
        overrides: [
          studentDaoProvider.overrideWithValue(
            _FakeStudentDao([
              StudentWithMeta(_student('student-a', name: 'Alex'), null),
              StudentWithMeta(
                _student('student-b', name: 'Alex', parentName: 'Parent B'),
                null,
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(studentProvider.future);

      final displayNames = container.read(studentDisplayNameMapProvider);

      expect(displayNames['student-a'], 'Alex\uFF08stud\uFF09');
      expect(displayNames['student-b'], 'Alex\uFF08Parent B\uFF09');
    },
  );
}

Student _student(String id, {String? name, String? parentName}) {
  return Student(
    id: id,
    name: name ?? id,
    parentName: parentName,
    pricePerClass: 100,
    status: 'active',
    createdAt: 1,
    updatedAt: 1,
  );
}

class _FakeStudentDao extends StudentDao {
  final List<StudentWithMeta> students;

  _FakeStudentDao(this.students) : super(DatabaseHelper.instance);

  @override
  Future<List<StudentWithMeta>> getStudentsWithLastAttendance() async {
    return students;
  }
}
