import '../../models/dismissed_insight.dart';
import '../../services/dismissed_insight_policy.dart';
import '../database_helper.dart';

class DismissedInsightDao {
  final DatabaseHelper _db;
  DismissedInsightDao(this._db);

  Future<void> insert(DismissedInsight r) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'dismissed_insights',
        where: r.studentId != null
            ? 'insight_type = ? AND student_id = ?'
            : 'insight_type = ? AND student_id IS NULL',
        whereArgs: r.studentId != null
            ? [r.insightType, r.studentId]
            : [r.insightType],
      );
      await txn.insert('dismissed_insights', r.toMap());
    });
  }

  Future<DismissedInsight?> find(
    String insightType,
    String? studentId, {
    DateTime? now,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'dismissed_insights',
      where: studentId != null
          ? 'insight_type = ? AND student_id = ?'
          : 'insight_type = ? AND student_id IS NULL',
      whereArgs: studentId != null ? [insightType, studentId] : [insightType],
      orderBy: 'dismissed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final insight = _mapInsight(rows.first);
    return DismissedInsightPolicy.isActive(insight, now: now) ? insight : null;
  }

  Future<void> deleteByStudentAndType(
    String insightType,
    String? studentId,
  ) async {
    final db = await _db.database;
    await db.delete(
      'dismissed_insights',
      where: studentId != null
          ? 'insight_type = ? AND student_id = ?'
          : 'insight_type = ? AND student_id IS NULL',
      whereArgs: studentId != null ? [insightType, studentId] : [insightType],
    );
  }

  Future<void> deleteExpired({DateTime? now}) async {
    final db = await _db.database;
    final currentTime = now ?? DateTime.now();
    final rows = await db.query('dismissed_insights');
    final expiredIds = <String>[];
    for (final row in rows) {
      final insight = _mapInsight(row);
      if (!DismissedInsightPolicy.isActive(insight, now: currentTime)) {
        expiredIds.add(insight.id);
      }
    }
    if (expiredIds.isEmpty) return;
    final placeholders = List.filled(expiredIds.length, '?').join(',');
    await db.delete(
      'dismissed_insights',
      where: 'id IN ($placeholders)',
      whereArgs: expiredIds,
    );
  }

  /// Returns all active (non-expired) dismissed insights as a set of 'type:studentId' keys.
  Future<Set<String>> getAllActiveKeys({DateTime? now}) async {
    final db = await _db.database;
    final currentTime = now ?? DateTime.now();
    final rows = await db.query('dismissed_insights');
    final result = <String>{};
    for (final row in rows) {
      final insight = _mapInsight(row);
      if (!DismissedInsightPolicy.isActive(insight, now: currentTime)) {
        continue;
      }
      result.add('${insight.insightType}:${insight.studentId ?? ''}');
    }
    return result;
  }

  DismissedInsight _mapInsight(Map<String, Object?> row) {
    return DismissedInsight.fromMap(Map<String, dynamic>.from(row));
  }
}
