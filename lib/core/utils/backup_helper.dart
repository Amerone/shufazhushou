import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class BackupHelper {
  static String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  static Future<String> backup() async {
    // Flush WAL to ensure the .db file contains all data
    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}

    final dbPath = p.join(await getDatabasesPath(), 'calligraphy_assistant.db');
    final tempDir = await getTemporaryDirectory();
    final backupDir =
        Directory(p.join(tempDir.path, 'calligraphy_assistant_backups'));
    await backupDir.create(recursive: true);
    final dest = p.join(backupDir.path, 'backup_${_timestamp()}.db');
    await File(dbPath).copy(dest);
    return dest;
  }

  /// Pick a .db file and overwrite the current database.
  /// Returns true if restore succeeded, false if user cancelled.
  /// Throws on error.
  static Future<bool> restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null) return false;
    final srcPath = result.files.single.path;
    if (srcPath == null) return false;

    // Validate SQLite file header
    final srcFile = File(srcPath);
    final raf = await srcFile.open(mode: FileMode.read);
    try {
      final header = await raf.read(16);
      if (header.length < 15 ||
          String.fromCharCodes(header.take(15)) != 'SQLite format 3') {
        throw Exception('所选文件不是有效的数据库备份');
      }
    } finally {
      await raf.close();
    }

    final dbPath =
        p.join(await getDatabasesPath(), 'calligraphy_assistant.db');

    // Ensure databases directory exists (critical after app reinstall)
    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // Close DB before overwrite
    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await db.close();
    } catch (_) {
      // DB may not be open yet, ignore
    }
    DatabaseHelper.instance.resetForRestore();

    // Delete WAL and SHM journal files — they belong to the old database
    // and will corrupt the restored database if left in place.
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('$dbPath$suffix');
      if (await f.exists()) await f.delete();
    }

    await File(srcPath).copy(dbPath);
    return true;
  }
}
