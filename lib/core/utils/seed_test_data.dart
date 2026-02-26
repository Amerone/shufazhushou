import 'dart:math';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
final _random = Random(42);

const _names = [
  '张小明', '李思琪', '王子涵', '赵雨萱', '刘浩然',
  '陈美琪', '杨子轩', '黄诗涵', '周天佑', '吴欣怡',
  '郑博文', '孙雅琪', '马思远', '朱梓萱', '胡明轩',
  '林雨桐', '何子墨', '高艺涵', '罗天翔', '谢语嫣',
];

const _statuses = ['active', 'active', 'active', 'active', 'suspended'];
const _attendanceStatuses = ['present', 'present', 'present', 'late', 'absent', 'leave', 'trial'];

class SeedTestData {
  static Future<void> run(dynamic db) async {
    final studentIds = <String>[];
    final studentPrices = <String, double>{};
    final now = DateTime.now();

    for (var i = 0; i < _names.length; i++) {
      final id = _uuid.v4();
      studentIds.add(id);
      final price = (80 + _random.nextInt(12) * 10).toDouble();
      studentPrices[id] = price;
      final status = _statuses[i % _statuses.length];
      final ts = now.subtract(Duration(days: 180 + _random.nextInt(90))).millisecondsSinceEpoch;

      await db.insert('students', {
        'id': id,
        'name': _names[i],
        'parent_name': '${_names[i].substring(0, 1)}家长',
        'parent_phone': '138${(10000000 + _random.nextInt(89999999))}',
        'price_per_class': price,
        'status': status,
        'created_at': ts,
        'updated_at': ts,
      });
    }

    // 生成出勤记录
    for (final sid in studentIds) {
      final price = studentPrices[sid]!;
      for (var j = 0; j < 250; j++) {
        final daysAgo = _random.nextInt(365);
        final date = now.subtract(Duration(days: daysAgo));
        final dateStr = _fmtDate(date);
        final hour = 8 + _random.nextInt(12);
        final startTime = '${hour.toString().padLeft(2, '0')}:00';
        final endTime = '${(hour + 1).toString().padLeft(2, '0')}:00';
        final status = _attendanceStatuses[_random.nextInt(_attendanceStatuses.length)];
        final ts = date.millisecondsSinceEpoch;

        // 与 FeeCalculator 逻辑一致: present/late 收费, 其余为 0
        final feeAmount = (status == 'present' || status == 'late') ? price : 0.0;

        await db.insert('attendance', {
          'id': _uuid.v4(),
          'student_id': sid,
          'date': dateStr,
          'start_time': startTime,
          'end_time': endTime,
          'status': status,
          'price_snapshot': price,
          'fee_amount': feeAmount,
          'created_at': ts,
          'updated_at': ts,
        });
      }
    }

    // 生成缴费记录
    for (final sid in studentIds) {
      final count = 3 + _random.nextInt(3);
      for (var j = 0; j < count; j++) {
        final daysAgo = _random.nextInt(300);
        final date = now.subtract(Duration(days: daysAgo));
        await db.insert('payments', {
          'id': _uuid.v4(),
          'student_id': sid,
          'amount': (500 + _random.nextInt(20) * 100).toDouble(),
          'payment_date': _fmtDate(date),
          'note': '第${j + 1}次缴费',
          'created_at': date.millisecondsSinceEpoch,
        });
      }
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
