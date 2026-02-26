import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/student.dart';
import '../database/dao/student_dao.dart';

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
      return const ImportPreview(total: 0, skipped: 0, toInsert: [], errors: []);
    }

    // 解析列名（第一行）
    final header = rows.first
        .map((c) => _normalize(c?.value?.toString() ?? ''))
        .toList();
    int col(String name) => header.indexOf(_normalize(name));

    final nameCol = col('姓名');
    if (nameCol < 0) {
      return const ImportPreview(
          total: 0, skipped: 0, toInsert: [], errors: ['未找到"姓名"列']);
    }
    final parentNameCol = col('家长姓名');
    final parentPhoneCol = col('家长电话');
    final priceCol = col('单价');

    final existingNames = existing.map((s) => s.name).toSet();
    final toInsert = <Student>[];
    final errors = <String>[];
    int skipped = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = row.length > nameCol
          ? (row[nameCol]?.value?.toString().trim() ?? '')
          : '';
      if (name.isEmpty) {
        errors.add('第 ${i + 1} 行：姓名为空，已跳过');
        skipped++;
        continue;
      }
      if (existingNames.contains(name)) {
        skipped++;
        continue;
      }
      double price = 0;
      if (priceCol >= 0 && row.length > priceCol) {
        price = double.tryParse(
                row[priceCol]?.value?.toString().trim() ?? '') ??
            0;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      toInsert.add(Student(
        id: const Uuid().v4(),
        name: name,
        parentName: parentNameCol >= 0 && row.length > parentNameCol
            ? row[parentNameCol]?.value?.toString().trim()
            : null,
        parentPhone: parentPhoneCol >= 0 && row.length > parentPhoneCol
            ? row[parentPhoneCol]?.value?.toString().trim()
            : null,
        pricePerClass: price,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ));
      existingNames.add(name);
    }

    return ImportPreview(
      total: rows.length - 1,
      skipped: skipped,
      toInsert: toInsert,
      errors: errors,
    );
  }

  static Future<void> commit(
      ImportPreview preview, StudentDao dao) async {
    await dao.batchInsert(preview.toInsert);
  }
}
