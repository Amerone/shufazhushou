import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/dao/student_dao.dart';
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
        () => ref.read(studentDaoProvider).getStudentsWithLastAttendance());
  }
}

final studentProvider =
    AsyncNotifierProvider<StudentNotifier, List<StudentWithMeta>>(
        StudentNotifier.new);
