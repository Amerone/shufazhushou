import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../database/dao/student_dao.dart';
import '../models/student.dart';

class ImportPreview {
  final int total;
  final int skipped;
  final List<Student> toInsert;
  final List<String> errors;

  const ImportPreview({
    required this.total,
    required this.skipped,
    required this.toInsert,
    required this.errors,
  });
}

class ExcelImporter {
  static String _normalize(String s) =>
      s.replaceAll(' ', '').replaceAll('\u3000', '').toLowerCase();

  static String _identityKey({
    required String name,
    String? parentName,
    String? parentPhone,
  }) {
    return [
      _normalize(name),
      _normalize(parentName ?? ''),
      _normalize(parentPhone ?? ''),
    ].join('|');
  }

  static int _findColumn(List<String> header, List<String> aliases) {
    for (final alias in aliases) {
      final index = header.indexOf(_normalize(alias));
      if (index >= 0) return index;
    }
    return -1;
  }

  static Future<ImportPreview?> pick(List<Student> existing) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return null;
    return parse(result.files.single.bytes!, existing);
  }

  static ImportPreview parse(List<int> bytes, List<Student> existing) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) {
      return const ImportPreview(
        total: 0,
        skipped: 0,
        toInsert: [],
        errors: [],
      );
    }

    // 解析列名（第一行）
    final header = rows.first
        .map((c) => _normalize(c?.value?.toString() ?? ''))
        .toList();
    final nameCol = _findColumn(header, ['姓名', '学生姓名']);
    if (nameCol < 0) {
      return const ImportPreview(
        total: 0,
        skipped: 0,
        toInsert: [],
        errors: ['未找到“姓名”或“学生姓名”列'],
      );
    }
    final parentNameCol = _findColumn(header, ['家长姓名']);
    final parentPhoneCol = _findColumn(header, ['家长电话']);
    final priceCol = _findColumn(header, ['单价', '课时单价']);

    final existingKeys = existing
        .map(
          (student) => _identityKey(
            name: student.name,
            parentName: student.parentName,
            parentPhone: student.parentPhone,
          ),
        )
        .toSet();
    final toInsert = <Student>[];
    final errors = <String>[];
    var skipped = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = row.length > nameCol
          ? (row[nameCol]?.value?.toString().trim() ?? '')
          : '';
      if (name.isEmpty) {
        errors.add('第 ${i + 1} 行：姓名为空，已跳过');
        skipped++;
        continue;
      }
      final parentName = parentNameCol >= 0 && row.length > parentNameCol
          ? row[parentNameCol]?.value?.toString().trim()
          : null;
      final parentPhone = parentPhoneCol >= 0 && row.length > parentPhoneCol
          ? row[parentPhoneCol]?.value?.toString().trim()
          : null;
      final identityKey = _identityKey(
        name: name,
        parentName: parentName,
        parentPhone: parentPhone,
      );
      if (existingKeys.contains(identityKey)) {
        skipped++;
        continue;
      }

      var price = 0.0;
      if (priceCol >= 0 && row.length > priceCol) {
        price =
            double.tryParse(row[priceCol]?.value?.toString().trim() ?? '') ?? 0;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      toInsert.add(
        Student(
          id: const Uuid().v4(),
          name: name,
          parentName: parentName,
          parentPhone: parentPhone,
          pricePerClass: price,
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      );
      existingKeys.add(identityKey);
    }

    return ImportPreview(
      total: rows.length - 1,
      skipped: skipped,
      toInsert: toInsert,
      errors: errors,
    );
  }

  static Future<void> commit(ImportPreview preview, StudentDao dao) async {
    await dao.batchInsert(preview.toInsert);
  }
}
