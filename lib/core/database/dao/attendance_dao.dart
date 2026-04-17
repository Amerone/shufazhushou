import '../../models/attendance.dart';
import '../../services/attendance_artwork_storage_service.dart';
import '../../utils/ledger_record_validator.dart';
import '../database_helper.dart';

class AttendanceDao {
  final DatabaseHelper _db;
  AttendanceDao(this._db);

  Future<void> insert(Attendance r) async {
    LedgerRecordValidator.validateAttendance(r);
    final db = await _db.database;
    await db.insert('attendance', r.toMap());
  }

  Future<void> update(Attendance r) async {
    LedgerRecordValidator.validateAttendance(r);
    final db = await _db.database;
    await db.update(
      'attendance',
      r.toMap(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    final existing = await getById(id);
    await db.delete('attendance', where: 'id = ?', whereArgs: [id]);
    await const AttendanceArtworkStorageService().deleteArtwork(
      existing?.artworkImagePath,
    );
  }

  Future<Attendance?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Attendance.fromMap(rows.first);
  }

  /// Batch insert attendance records within a transaction.
  /// For each record, deletes any conflicting record (by id) before inserting.
  Future<void> batchInsertWithConflictReplace(
    List<Attendance> records,
    Map<String, String> conflictIds,
  ) async {
    for (final record in records) {
      LedgerRecordValidator.validateAttendance(record);
    }
    final db = await _db.database;
    final obsoleteArtworkPaths = <String>{};
    await db.transaction((txn) async {
      for (final record in records) {
        final oldId = conflictIds[record.studentId];
        if (oldId != null) {
          final oldRows = await txn.query(
            'attendance',
            columns: const ['artwork_image_path'],
            where: 'id = ?',
            whereArgs: [oldId],
            limit: 1,
          );
          final oldArtworkPath =
              oldRows.firstOrNull?['artwork_image_path'] as String?;
          if (oldArtworkPath?.trim().isNotEmpty == true) {
            obsoleteArtworkPaths.add(oldArtworkPath!.trim());
          }
          await txn.delete('attendance', where: 'id = ?', whereArgs: [oldId]);
        }
        await txn.insert('attendance', record.toMap());
      }
    });

    const artworkStorage = AttendanceArtworkStorageService();
    for (final artworkPath in obsoleteArtworkPaths) {
      await artworkStorage.deleteArtwork(artworkPath);
    }
  }

  Future<List<Attendance>> getByDate(String date) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<List<Attendance>> getByStudent(String studentId) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC, start_time DESC, created_at DESC',
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<List<Attendance>> getByStudentPaged(
    String studentId,
    int limit,
    int offset,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC, start_time DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<List<Attendance>> getByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT * FROM attendance
      WHERE student_id = ?
        AND (? IS NULL OR date >= ?)
        AND (? IS NULL OR date <= ?)
      ORDER BY date DESC
    ''',
      [studentId, from, from, to, to],
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<double> getTotalFeeByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(fee_amount), 0) AS total
      FROM attendance
      WHERE student_id = ?
        AND (? IS NULL OR date >= ?)
        AND (? IS NULL OR date <= ?)
    ''',
      [studentId, from, from, to, to],
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<List<Attendance>> getByDateRange(String from, String to) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from, to],
      orderBy: 'date DESC',
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<Attendance?> findConflict(
    String studentId,
    String date,
    String startTime,
    String endTime, {
    String? excludeId,
  }) async {
    final db = await _db.database;
    String where =
        'student_id = ? AND date = ? AND start_time < ? AND end_time > ?';
    final args = <Object>[studentId, date, endTime, startTime];
    if (excludeId != null) {
      where += ' AND id != ?';
      args.add(excludeId);
    }
    final rows = await db.query('attendance', where: where, whereArgs: args);
    return rows.isEmpty ? null : Attendance.fromMap(rows.first);
  }

  /// Batch checks time-range conflicts for multiple students on a date.
  /// Returns at most one conflicting record per student_id.
  Future<Map<String, Attendance>> findConflictsForStudents(
    Iterable<String> studentIds,
    String date,
    String startTime,
    String endTime, {
    String? excludeId,
  }) async {
    final ids = studentIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const <String, Attendance>{};

    final db = await _db.database;
    final result = <String, Attendance>{};
    const batchSize = 800;

    for (var start = 0; start < ids.length; start += batchSize) {
      var end = start + batchSize;
      if (end > ids.length) {
        end = ids.length;
      }
      final batchIds = ids.sublist(start, end);
      final placeholders = List.filled(batchIds.length, '?').join(', ');
      var where =
          'student_id IN ($placeholders) AND date = ? AND start_time < ? AND end_time > ?';
      final args = <Object>[...batchIds, date, endTime, startTime];
      if (excludeId != null) {
        where += ' AND id != ?';
        args.add(excludeId);
      }

      final rows = await db.query(
        'attendance',
        where: where,
        whereArgs: args,
        orderBy: 'student_id ASC, start_time ASC, created_at ASC',
      );

      for (final row in rows) {
        final record = Attendance.fromMap(row);
        result.putIfAbsent(record.studentId, () => record);
      }
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> getMonthlyRevenue(
    String from,
    String to,
  ) async {
    final db = await _db.database;
    return db.rawQuery(
      '''
      SELECT strftime('%Y-%m', date) AS month, SUM(fee_amount) AS totalFee
      FROM attendance
      WHERE date >= ? AND date <= ?
      GROUP BY month
      ORDER BY month
    ''',
      [from, to],
    );
  }

  Future<List<Map<String, dynamic>>> getStudentContribution(
    String from,
    String to,
  ) async {
    final db = await _db.database;
    return db.rawQuery(
      '''
      SELECT a.student_id AS studentId, s.name AS studentName,
             COUNT(*) AS attendanceCount, COALESCE(SUM(a.fee_amount), 0) AS totalFee,
             COALESCE(SUM(CASE WHEN a.status='present' THEN 1 ELSE 0 END), 0) AS presentCount,
             COALESCE(SUM(CASE WHEN a.status='late' THEN 1 ELSE 0 END), 0) AS lateCount,
             COALESCE(SUM(CASE WHEN a.status='absent' THEN 1 ELSE 0 END), 0) AS absentCount,
             COALESCE(SUM(CASE WHEN a.status='leave' THEN 1 ELSE 0 END), 0) AS leaveCount,
             COALESCE(SUM(CASE WHEN a.status='trial' THEN 1 ELSE 0 END), 0) AS trialCount
      FROM attendance a
      JOIN students s ON s.id = a.student_id
      WHERE a.date >= ? AND a.date <= ?
      GROUP BY a.student_id
      ORDER BY totalFee DESC
    ''',
      [from, to],
    );
  }

  Future<List<Map<String, dynamic>>> getTimeHeatmap(
    String from,
    String to,
  ) async {
    final db = await _db.database;
    return db.rawQuery(
      '''
      SELECT
        CAST(strftime('%w', date) AS INTEGER) AS weekday,
        CAST(substr(start_time, 1, 2) AS INTEGER) AS hour,
        COUNT(*) AS count
      FROM attendance
      WHERE date >= ? AND date <= ?
        AND status IN ('present','late','trial')
      GROUP BY weekday, hour
    ''',
      [from, to],
    );
  }

  Future<List<Map<String, dynamic>>> getStatusDistribution(
    String from,
    String to,
  ) async {
    final db = await _db.database;
    return db.rawQuery(
      '''
      SELECT status, COUNT(*) AS count
      FROM attendance
      WHERE date >= ? AND date <= ?
      GROUP BY status
    ''',
      [from, to],
    );
  }

  Future<List<Attendance>> getByDateRangeAndStatus(
    String from,
    String to,
    String status,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'date >= ? AND date <= ? AND status = ?',
      whereArgs: [from, to, status],
      orderBy: 'date DESC',
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<Map<String, dynamic>> getMetrics(String from, String to) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(fee_amount), 0) AS totalFee,
        COALESCE(SUM(CASE WHEN status='present' THEN 1 ELSE 0 END), 0) AS presentCount,
        COALESCE(SUM(CASE WHEN status='late' THEN 1 ELSE 0 END), 0) AS lateCount,
        COALESCE(SUM(CASE WHEN status='absent' THEN 1 ELSE 0 END), 0) AS absentCount,
        COALESCE(
          COUNT(
            DISTINCT CASE
              WHEN status IN ('present','late','trial') THEN student_id
            END
          ),
          0
        ) AS activeStudentCount
      FROM attendance
      WHERE date >= ? AND date <= ?
    ''',
      [from, to],
    );
    return rows.first;
  }

  /// Returns all attendance records grouped by student_id.
  Future<Map<String, List<Attendance>>> getAllGroupedByStudent() async {
    final db = await _db.database;
    final rows = await db.query('attendance', orderBy: 'date DESC');
    final result = <String, List<Attendance>>{};
    for (final row in rows) {
      final record = Attendance.fromMap(row);
      result.putIfAbsent(record.studentId, () => []).add(record);
    }
    return result;
  }
}
