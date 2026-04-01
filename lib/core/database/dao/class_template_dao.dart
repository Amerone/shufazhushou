import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../models/class_template.dart';
import '../database_helper.dart';

class BuiltinClassTemplateSeed {
  final String name;
  final String startTime;
  final String endTime;

  const BuiltinClassTemplateSeed({
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  String get slotKey => '$startTime|$endTime';
}

const builtinClassTemplateSeeds = <BuiltinClassTemplateSeed>[
  BuiltinClassTemplateSeed(
    name: '周内 18:00-19:00',
    startTime: '18:00',
    endTime: '19:00',
  ),
  BuiltinClassTemplateSeed(
    name: '周内 19:00-20:00',
    startTime: '19:00',
    endTime: '20:00',
  ),
  BuiltinClassTemplateSeed(
    name: '周末 08:30-09:30',
    startTime: '08:30',
    endTime: '09:30',
  ),
  BuiltinClassTemplateSeed(
    name: '周末 09:30-10:30',
    startTime: '09:30',
    endTime: '10:30',
  ),
  BuiltinClassTemplateSeed(
    name: '周末 10:30-11:30',
    startTime: '10:30',
    endTime: '11:30',
  ),
];

List<BuiltinClassTemplateSeed> resolveMissingBuiltinTemplateSeeds({
  required Iterable<ClassTemplate> existingTemplates,
  Iterable<BuiltinClassTemplateSeed> builtinSeeds = builtinClassTemplateSeeds,
}) {
  final existingSlotKeys = existingTemplates
      .map((template) => '${template.startTime}|${template.endTime}')
      .toSet();

  return builtinSeeds
      .where((seed) => !existingSlotKeys.contains(seed.slotKey))
      .toList(growable: false);
}

class ClassTemplateDao {
  static const _builtinTemplateSeedVersion = 1;
  static const _builtinTemplateSeedVersionKey =
      'builtin_class_template_seed_version';

  final DatabaseHelper _db;
  ClassTemplateDao(this._db);

  Future<void> insert(ClassTemplate t) async {
    final db = await _db.database;
    await db.insert('class_templates', t.toMap());
  }

  Future<void> update(ClassTemplate t) async {
    final db = await _db.database;
    await db.update(
      'class_templates',
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('class_templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ClassTemplate>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('class_templates', orderBy: 'created_at ASC');
    return rows.map(ClassTemplate.fromMap).toList();
  }

  Future<int> ensureBuiltinTemplates({bool force = false}) async {
    final db = await _db.database;
    final seedRows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_builtinTemplateSeedVersionKey],
      limit: 1,
    );
    final currentSeedVersion = seedRows.isEmpty
        ? null
        : int.tryParse(seedRows.first['value']?.toString() ?? '');
    if (!force && currentSeedVersion == _builtinTemplateSeedVersion) {
      return 0;
    }

    final existingTemplates = await getAll();
    final missingSeeds = resolveMissingBuiltinTemplateSeeds(
      existingTemplates: existingTemplates,
    );
    if (missingSeeds.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final batch = db.batch();
      for (var i = 0; i < missingSeeds.length; i++) {
        final seed = missingSeeds[i];
        batch.insert(
          'class_templates',
          ClassTemplate(
            id: const Uuid().v4(),
            name: seed.name,
            startTime: seed.startTime,
            endTime: seed.endTime,
            createdAt: now + i,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    }

    await db.insert('settings', {
      'key': _builtinTemplateSeedVersionKey,
      'value': _builtinTemplateSeedVersion.toString(),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return missingSeeds.length;
  }
}
