import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static const databaseFileName = 'moyun.db';
  static const legacyDatabaseFileName = 'calligraphy_assistant.db';
  static const databaseVersion = 5;
  static const _legacySuffixes = ['-wal', '-shm', '-journal'];

  Future<Database>? _dbFuture;

  Future<Database> get database {
    _dbFuture ??= _initDB();
    return _dbFuture!;
  }

  void resetForRestore() {
    _dbFuture = null;
  }

  Future<Database> _initDB() async {
    final path = await resolveDatabasePath();
    return openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  static Future<String> resolveDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    final currentPath = join(databasesPath, databaseFileName);
    if (await databaseExists(currentPath)) {
      return currentPath;
    }

    final legacyPath = join(databasesPath, legacyDatabaseFileName);
    if (await databaseExists(legacyPath)) {
      await _migrateLegacyDatabaseFiles(
        legacyPath: legacyPath,
        currentPath: currentPath,
      );
    }

    return currentPath;
  }

  static Future<void> _migrateLegacyDatabaseFiles({
    required String legacyPath,
    required String currentPath,
  }) async {
    final legacyFile = File(legacyPath);
    if (!await legacyFile.exists()) {
      return;
    }

    await legacyFile.rename(currentPath);

    for (final suffix in _legacySuffixes) {
      final legacySidecar = File('$legacyPath$suffix');
      if (!await legacySidecar.exists()) {
        continue;
      }

      final currentSidecar = File('$currentPath$suffix');
      if (await currentSidecar.exists()) {
        await currentSidecar.delete();
      }
      await legacySidecar.rename(currentSidecar.path);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_name TEXT,
        parent_phone TEXT,
        price_per_class REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        status TEXT NOT NULL,
        price_snapshot REAL NOT NULL DEFAULT 0,
        fee_amount REAL NOT NULL DEFAULT 0,
        note TEXT,
        lesson_focus_tags TEXT,
        home_practice_note TEXT,
        progress_scores_json TEXT,
        artwork_image_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_attendance_student_date ON attendance(student_id, date)',
    );
    await db.execute('CREATE INDEX idx_attendance_date ON attendance(date)');
    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_payments_student ON payments(student_id)',
    );
    await db.execute('''
      CREATE TABLE class_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE dismissed_insights (
        id TEXT PRIMARY KEY,
        insight_type TEXT NOT NULL,
        student_id TEXT,
        dismissed_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'students', 'note TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS fee_adjustments');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dismissed_insights (
          id TEXT PRIMARY KEY,
          insight_type TEXT NOT NULL,
          student_id TEXT,
          dismissed_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await _addColumnIfMissing(db, 'attendance', 'lesson_focus_tags TEXT');
      await _addColumnIfMissing(db, 'attendance', 'home_practice_note TEXT');
      await _addColumnIfMissing(db, 'attendance', 'progress_scores_json TEXT');
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'attendance', 'artwork_image_path TEXT');
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    String columnSql,
  ) async {
    final columnName = columnSql.split(' ').first.trim();
    final columnRows = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columnRows.any((row) => row['name'] == columnName);
    if (exists) return;
    await db.execute('ALTER TABLE $tableName ADD COLUMN $columnSql');
  }
}
