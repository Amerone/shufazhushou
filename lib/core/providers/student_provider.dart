import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dao/student_dao.dart';
import '../models/student.dart' show Student, buildDisplayNameMap;
import 'database_provider.dart';

final studentDaoProvider = Provider<StudentDao>((ref) {
  return StudentDao(ref.watch(databaseProvider));
});

class StudentNotifier extends AsyncNotifier<List<StudentWithMeta>> {
  @override
  Future<List<StudentWithMeta>> build() {
    return ref.watch(studentDaoProvider).getStudentsWithLastAttendance();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(studentDaoProvider).getStudentsWithLastAttendance(),
    );
  }
}

final studentProvider =
    AsyncNotifierProvider<StudentNotifier, List<StudentWithMeta>>(
      StudentNotifier.new,
    );

class StudentRosterSummary {
  final int count;
  final Set<String> ids;
  final String _idsSignature;

  const StudentRosterSummary._({
    required this.count,
    required this.ids,
    required String idsSignature,
  }) : _idsSignature = idsSignature;

  static const empty = StudentRosterSummary._(
    count: 0,
    ids: <String>{},
    idsSignature: '',
  );

  factory StudentRosterSummary.fromStudents(List<StudentWithMeta> students) {
    if (students.isEmpty) {
      return empty;
    }

    final ids = students.map((item) => item.student.id).toList(growable: false)
      ..sort();
    return StudentRosterSummary._(
      count: students.length,
      ids: Set.unmodifiable(ids),
      idsSignature: ids.join('\u001f'),
    );
  }

  bool get hasStudents => count > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentRosterSummary &&
          count == other.count &&
          _idsSignature == other._idsSignature;

  @override
  int get hashCode => Object.hash(count, _idsSignature);
}

/// Keeps home-level consumers from watching the full student/meta list.
final studentRosterSummaryProvider = Provider<StudentRosterSummary>((ref) {
  final students =
      ref.watch(studentProvider).valueOrNull ?? const <StudentWithMeta>[];
  return StudentRosterSummary.fromStudents(students);
});

/// Reuses studentProvider data to avoid rebuilding display-name map in widgets.
final studentDisplayNameMapProvider = Provider<Map<String, String>>((ref) {
  final students = ref.watch(studentProvider).valueOrNull ?? const [];
  if (students.isEmpty) {
    return const <String, String>{};
  }
  return buildDisplayNameMap(
    students.map((item) => item.student).toList(growable: false),
  );
});

/// Reuses studentProvider data to avoid rebuilding id -> student map in widgets.
final studentByIdMapProvider = Provider<Map<String, Student>>((ref) {
  final students = ref.watch(studentProvider).valueOrNull ?? const [];
  if (students.isEmpty) {
    return const <String, Student>{};
  }

  return {for (final item in students) item.student.id: item.student};
});
