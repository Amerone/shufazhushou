import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class SettingsDao {
  final DatabaseHelper _db;
  SettingsDao(this._db);

  Future<String?> get(String key) async {
    final db = await _db.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await _db.database;
    await db.insert('settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String key) async {
    final db = await _db.database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  Future<Map<String, String>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('settings');
    return {
      for (final r in rows) r['key'] as String: (r['value'] as String?) ?? '',
    };
  }
}
