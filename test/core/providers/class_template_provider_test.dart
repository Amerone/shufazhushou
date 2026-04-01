import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/class_template_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/class_template.dart';
import 'package:moyun/core/providers/class_template_provider.dart';

void main() {
  test('provider build ensures builtin templates before reading', () async {
    final fakeDao = _FakeClassTemplateDao(
      initialTemplates: const [
        ClassTemplate(
          id: '1',
          name: '自定义模板',
          startTime: '14:00',
          endTime: '15:00',
          createdAt: 1,
        ),
      ],
      ensureReturn: 2,
    );

    final container = ProviderContainer(
      overrides: [classTemplateDaoProvider.overrideWithValue(fakeDao)],
    );
    addTearDown(container.dispose);

    final templates = await container.read(classTemplateProvider.future);

    expect(fakeDao.ensureCallCount, 1);
    expect(fakeDao.getAllCallCount, 1);
    expect(templates, hasLength(1));
  });

  test('notifier ensureBuiltinTemplates triggers reload', () async {
    final fakeDao = _FakeClassTemplateDao(
      initialTemplates: const [],
      ensureReturn: 1,
    );

    final container = ProviderContainer(
      overrides: [classTemplateDaoProvider.overrideWithValue(fakeDao)],
    );
    addTearDown(container.dispose);

    await container.read(classTemplateProvider.future);
    fakeDao.resetCallStats();

    final inserted = await container
        .read(classTemplateProvider.notifier)
        .ensureBuiltinTemplates(force: true);

    expect(inserted, 1);
    expect(fakeDao.ensureCallCount, 1);
    expect(fakeDao.ensureForceArguments, orderedEquals([isTrue]));
    expect(fakeDao.getAllCallCount, 1);
  });
}

class _FakeClassTemplateDao extends ClassTemplateDao {
  _FakeClassTemplateDao({
    required List<ClassTemplate> initialTemplates,
    required this.ensureReturn,
  }) : _templates = List<ClassTemplate>.from(initialTemplates),
       super(DatabaseHelper.instance);

  final List<ClassTemplate> _templates;
  final int ensureReturn;
  int ensureCallCount = 0;
  int getAllCallCount = 0;
  final ensureForceArguments = <bool>[];

  void resetCallStats() {
    ensureCallCount = 0;
    getAllCallCount = 0;
    ensureForceArguments.clear();
  }

  @override
  Future<int> ensureBuiltinTemplates({bool force = false}) async {
    ensureCallCount += 1;
    ensureForceArguments.add(force);
    return ensureReturn;
  }

  @override
  Future<List<ClassTemplate>> getAll() async {
    getAllCallCount += 1;
    return List<ClassTemplate>.from(_templates);
  }
}
