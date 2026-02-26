import '../../models/student.dart';
import '../database_helper.dart';

class StudentWithMeta {
  final Student student;
  final String? lastAttendanceDate;
  const StudentWithMeta(this.student, this.lastAttendanceDate);
}

class StudentDao {
  final DatabaseHelper _db;
  StudentDao(this._db);

  Future<void> insert(Student s) async {
    final db = await _db.database;
    await db.insert('students', s.toMap());
  }

  Future<void> update(Student s) async {
    final db = await _db.database;
    await db.update('students', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<Student?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query('students', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Student.fromMap(rows.first);
  }

  Future<List<Student>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('students', orderBy: 'created_at DESC');
    return rows.map(Student.fromMap).toList();
  }

  Future<List<Student>> search(String keyword) async {
    final db = await _db.database;
    final rows = await db.query(
      'students',
      where: 'name LIKE ? OR parent_phone LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
    );
    return rows.map(Student.fromMap).toList();
  }

  Future<void> batchInsert(List<Student> students) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final s in students) {
      batch.insert('students', s.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<StudentWithMeta>> getStudentsWithLastAttendance() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT s.*,
        (SELECT MAX(date) FROM attendance
         WHERE student_id = s.id AND status IN ('present','late')) AS last_attendance_date
      FROM students s
      ORDER BY s.created_at DESC
    ''');
    return rows.map((r) {
      final student = Student.fromMap(r);
      final last = r['last_attendance_date'] as String?;
      return StudentWithMeta(student, last);
    }).toList();
  }
}
