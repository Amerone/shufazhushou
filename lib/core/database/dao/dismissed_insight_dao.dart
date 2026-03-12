import '../../models/dismissed_insight.dart';
import '../database_helper.dart';

class DismissedInsightDao {
  final DatabaseHelper _db;
  DismissedInsightDao(this._db);

  Future<void> insert(DismissedInsight r) async {
    final db = await _db.database;
    await db.insert('dismissed_insights', r.toMap());
  }

  Future<DismissedInsight?> find(String insightType, String? studentId) async {
    final db = await _db.database;
    final rows = await db.query(
      'dismissed_insights',
      where: studentId != null
          ? 'insight_type = ? AND student_id = ?'
          : 'insight_type = ? AND student_id IS NULL',
      whereArgs: studentId != null ? [insightType, studentId] : [insightType],
    );
    return rows.isEmpty ? null : DismissedInsight.fromMap(rows.first);
  }

  Future<void> deleteByStudentAndType(
      String insightType, String? studentId) async {
    final db = await _db.database;
    await db.delete(
      'dismissed_insights',
      where: studentId != null
          ? 'insight_type = ? AND student_id = ?'
          : 'insight_type = ? AND student_id IS NULL',
      whereArgs: studentId != null ? [insightType, studentId] : [insightType],
    );
  }

  Future<void> deleteExpired() async {
    final db = await _db.database;
    await db.delete(
      'dismissed_insights',
      where: "insight_type = 'peak' AND dismissed_at < ?",
      whereArgs: [
        DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch,
      ],
    );
  }

  /// Returns all active (non-expired) dismissed insights as a set of 'type:studentId' keys.
  Future<Set<String>> getAllActiveKeys() async {
    final db = await _db.database;
    final rows = await db.query('dismissed_insights');
    final result = <String>{};
    for (final row in rows) {
      final type = row['insight_type'] as String;
      final studentId = row['student_id'] as String?;
      result.add('$type:${studentId ?? ''}');
    }
    return result;
  }
}
