import '../../models/payment.dart';
import '../database_helper.dart';

class PaymentDao {
  final DatabaseHelper _db;
  PaymentDao(this._db);

  Future<void> insert(Payment p) async {
    final db = await _db.database;
    await db.insert('payments', p.toMap());
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Payment>> getByStudent(String studentId) async {
    final db = await _db.database;
    final rows = await db.query('payments',
        where: 'student_id = ?', whereArgs: [studentId], orderBy: 'payment_date DESC');
    return rows.map(Payment.fromMap).toList();
  }

  Future<double> getTotalByStudent(String studentId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE student_id = ?',
        [studentId]);
    return (rows.first['total'] as num).toDouble();
  }

  Future<double> getTotalByStudentAndDateRange(
      String studentId, String? from, String? to) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount),0) AS total FROM payments
      WHERE student_id = ?
        AND (? IS NULL OR payment_date >= ?)
        AND (? IS NULL OR payment_date <= ?)
    ''', [studentId, from, from, to, to]);
    return (rows.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getMonthlyReceived(
      String from, String to) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT strftime('%Y-%m', payment_date) AS month,
             SUM(amount) AS totalReceived
      FROM payments
      WHERE payment_date >= ? AND payment_date <= ?
      GROUP BY month
      ORDER BY month
    ''', [from, to]);
  }
}
