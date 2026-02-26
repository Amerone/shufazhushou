import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/dao/class_template_dao.dart';
import '../models/class_template.dart';
import 'database_provider.dart';

final classTemplateDaoProvider = Provider((ref) =>
    ClassTemplateDao(ref.watch(databaseProvider)));

class ClassTemplateNotifier extends AsyncNotifier<List<ClassTemplate>> {
  @override
  Future<List<ClassTemplate>> build() {
    return ref.watch(classTemplateDaoProvider).getAll();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(classTemplateDaoProvider).getAll());
  }
}

final classTemplateProvider =
    AsyncNotifierProvider<ClassTemplateNotifier, List<ClassTemplate>>(
        ClassTemplateNotifier.new);
