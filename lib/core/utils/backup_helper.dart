import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class BackupHelper {
  static String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  static Future<String> backup() async {
    final dbPath = p.join(await getDatabasesPath(), 'calligraphy_assistant.db');
    final downloadsDir = Directory('/storage/emulated/0/Download/书法助手备份');
    await downloadsDir.create(recursive: true);
    final dest = p.join(downloadsDir.path, 'backup_${_timestamp()}.db');
    await File(dbPath).copy(dest);
    return dest;
  }

  /// Pick a .db file and overwrite the current database.
  /// Returns true if restore succeeded, false if user cancelled.
  /// Throws on error.
  static Future<bool> restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      withData: false,
    );
    if (result == null) return false;
    final srcPath = result.files.single.path;
    if (srcPath == null) return false;

    final dbPath = p.join(await getDatabasesPath(), 'calligraphy_assistant.db');
    // Close DB before overwrite
    try {
      final db = await DatabaseHelper.instance.database;
      await db.close();
    } catch (_) {
      // DB may not be open yet, ignore
    }
    DatabaseHelper.instance.resetForRestore();
    await File(srcPath).copy(dbPath);
    return true;
  }
}
