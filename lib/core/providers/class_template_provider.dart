import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/dao/class_template_dao.dart';
import '../models/class_template.dart';
import 'database_provider.dart';

final classTemplateDaoProvider = Provider(
  (ref) => ClassTemplateDao(ref.watch(databaseProvider)),
);

class ClassTemplateNotifier extends AsyncNotifier<List<ClassTemplate>> {
  @override
  Future<List<ClassTemplate>> build() async {
    final dao = ref.watch(classTemplateDaoProvider);
    await dao.ensureBuiltinTemplates();
    return dao.getAll();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dao = ref.read(classTemplateDaoProvider);
      await dao.ensureBuiltinTemplates();
      return dao.getAll();
    });
  }

  Future<int> ensureBuiltinTemplates({bool force = false}) async {
    final dao = ref.read(classTemplateDaoProvider);
    final inserted = await dao.ensureBuiltinTemplates(force: force);
    state = const AsyncLoading();
    state = await AsyncValue.guard(dao.getAll);
    return inserted;
  }
}

final classTemplateProvider =
    AsyncNotifierProvider<ClassTemplateNotifier, List<ClassTemplate>>(
      ClassTemplateNotifier.new,
    );
