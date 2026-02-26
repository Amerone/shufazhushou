import '../../models/class_template.dart';
import '../database_helper.dart';

class ClassTemplateDao {
  final DatabaseHelper _db;
  ClassTemplateDao(this._db);

  Future<void> insert(ClassTemplate t) async {
    final db = await _db.database;
    await db.insert('class_templates', t.toMap());
  }

  Future<void> update(ClassTemplate t) async {
    final db = await _db.database;
    await db.update('class_templates', t.toMap(),
        where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('class_templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ClassTemplate>> getAll() async {
    final db = await _db.database;
    final rows =
        await db.query('class_templates', orderBy: 'created_at ASC');
    return rows.map(ClassTemplate.fromMap).toList();
  }
}
