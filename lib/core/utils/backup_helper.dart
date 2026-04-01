import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class BackupRecord {
  final String path;
  final String fileName;
  final DateTime modifiedAt;
  final int sizeInBytes;

  const BackupRecord({
    required this.path,
    required this.fileName,
    required this.modifiedAt,
    required this.sizeInBytes,
  });
}

class BackupHelper {
  static const _backupDirectoryName = 'moyun_backups';
  static const _legacyBackupDirectoryName = 'calligraphy_assistant_backups';
  static const _backupFilePrefix = 'moyun_backup';
  static const encryptedBackupExtension = 'moyunbak';
  static const _minimumPassphraseLength = 8;
  static const minimumPassphraseLength = _minimumPassphraseLength;
  static const _encryptedBackupFormat = 'moyun_encrypted_backup';
  static const _encryptedBackupVersion = 1;
  static const _pbkdf2Iterations = 120000;
  static const _kdfSaltLength = 16;
  static const _gcmNonceLength = 12;
  static const _snapshotExtensions = <String>{'db', 'sqlite', 'sqlite3'};
  static const _restoreExtensions = <String>{
    ..._snapshotExtensions,
    encryptedBackupExtension,
  };

  static final _cipher = AesGcm.with256bits();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );

  @visibleForTesting
  static Future<Directory> Function()? applicationSupportDirectoryResolver;

  @visibleForTesting
  static Future<Directory?> Function()? externalStorageDirectoryResolver;

  @visibleForTesting
  static Future<Directory> Function()? temporaryDirectoryResolver;

  static Future<String> backup({DateTime? at}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}

    final dbPath = await DatabaseHelper.resolveDatabasePath();
    final backupDir = await _resolveBackupDirectory();
    final destination = p.join(backupDir.path, buildBackupFileName(at));
    await File(dbPath).copy(destination);
    return destination;
  }

  static Future<String> exportEncryptedBackup({
    required String passphrase,
    String? sourcePath,
    DateTime? at,
  }) async {
    final validationMessage = validatePassphrase(passphrase);
    if (validationMessage != null) {
      throw Exception(validationMessage);
    }

    final normalizedPassphrase = passphrase.trim();

    final resolvedSourcePath = sourcePath?.trim();
    final rawBackupPath =
        resolvedSourcePath == null || resolvedSourcePath.isEmpty
        ? await backup(at: at)
        : resolvedSourcePath;
    final rawBackupFile = File(rawBackupPath);
    if (!await rawBackupFile.exists()) {
      throw Exception('未找到待导出的备份文件，请重新生成后再试。');
    }

    final encryptedBytes = await encryptBackupBytes(
      await rawBackupFile.readAsBytes(),
      passphrase: normalizedPassphrase,
    );
    final tempDir = await _getTemporaryDirectory();
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    final exportPath = p.join(tempDir.path, buildEncryptedBackupFileName(at));
    await File(exportPath).writeAsBytes(encryptedBytes, flush: true);
    return exportPath;
  }

  static Future<List<BackupRecord>> listBackups() async {
    final backupDir = await _resolveBackupDirectory();
    if (!await backupDir.exists()) {
      return const <BackupRecord>[];
    }

    final records = <BackupRecord>[];
    await for (final entity in backupDir.list(followLinks: false)) {
      if (entity is! File || !_isSnapshotBackupFile(entity.path)) {
        continue;
      }

      final stat = await entity.stat();
      records.add(
        BackupRecord(
          path: entity.path,
          fileName: p.basename(entity.path),
          modifiedAt: stat.modified,
          sizeInBytes: stat.size,
        ),
      );
    }

    records.sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt));
    return records;
  }

  static Future<String?> pickRestoreSourcePath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _restoreExtensions.toList(growable: false),
    );
    if (result == null) return null;

    final srcPath = result.files.single.path;
    if (srcPath == null || srcPath.trim().isEmpty) {
      return null;
    }

    return srcPath;
  }

  static Future<String?> restore({String? passphrase}) async {
    final srcPath = await pickRestoreSourcePath();
    if (srcPath == null) {
      return null;
    }
    final restored = await restoreFromPath(srcPath, passphrase: passphrase);
    return restored ? srcPath : null;
  }

  static Future<bool> restoreFromPath(
    String srcPath, {
    String? passphrase,
  }) async {
    final normalizedPath = srcPath.trim();
    if (normalizedPath.isEmpty) return false;
    if (!hasSupportedBackupExtension(normalizedPath)) {
      throw Exception(
        '请选择 .db、.sqlite、.sqlite3 或 .$encryptedBackupExtension 备份文件。',
      );
    }

    final sourceFile = File(normalizedPath);
    if (!await sourceFile.exists()) {
      throw Exception('未找到备份文件，请重新选择。');
    }

    String? decryptedTempPath;
    try {
      final restoreSource = await _prepareRestoreSource(
        sourceFile,
        passphrase: passphrase,
        onPrepared: (tempPath) => decryptedTempPath = tempPath,
      );
      await _validateBackupFile(restoreSource);

      final dbPath = await DatabaseHelper.resolveDatabasePath();
      final dbDir = Directory(p.dirname(dbPath));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      try {
        final db = await DatabaseHelper.instance.database;
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
        await db.close();
      } catch (_) {}
      DatabaseHelper.instance.resetForRestore();

      for (final suffix in ['-wal', '-shm', '-journal']) {
        final sidecar = File('$dbPath$suffix');
        if (await sidecar.exists()) {
          await sidecar.delete();
        }
      }

      await restoreSource.copy(dbPath);
      return true;
    } finally {
      if (decryptedTempPath != null) {
        final tempFile = File(decryptedTempPath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }
  }

  @visibleForTesting
  static String buildBackupFileName([DateTime? at]) {
    return '${_backupFilePrefix}_${_formatTimestamp(at ?? DateTime.now())}.db';
  }

  @visibleForTesting
  static String buildEncryptedBackupFileName([DateTime? at]) {
    return '${_backupFilePrefix}_${_formatTimestamp(at ?? DateTime.now())}.$encryptedBackupExtension';
  }

  static bool hasSupportedBackupExtension(String filePath) {
    return _isSupportedRestoreFile(filePath);
  }

  static bool isEncryptedBackupPath(String filePath) {
    final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    return extension == encryptedBackupExtension;
  }

  static String? validatePassphrase(String passphrase, {String? confirmation}) {
    final normalizedPassphrase = _normalizePassphrase(passphrase);
    if (normalizedPassphrase == null) {
      return '备份口令至少需要 $_minimumPassphraseLength 个字符。';
    }

    if (confirmation != null && confirmation.trim() != normalizedPassphrase) {
      return '两次输入的口令不一致。';
    }

    return null;
  }

  static Future<String> backupDirectoryPath() async {
    final backupDir = await _resolveBackupDirectory();
    return backupDir.path;
  }

  @visibleForTesting
  static Future<Uint8List> encryptBackupBytes(
    List<int> bytes, {
    required String passphrase,
  }) async {
    final validationMessage = validatePassphrase(passphrase);
    if (validationMessage != null) {
      throw Exception(validationMessage);
    }
    final normalizedPassphrase = passphrase.trim();

    final salt = _randomBytes(_kdfSaltLength);
    final nonce = _randomBytes(_gcmNonceLength);
    final secretKey = await _kdf.deriveKeyFromPassword(
      password: normalizedPassphrase,
      nonce: salt,
    );
    final secretBox = await _cipher.encrypt(
      bytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = _EncryptedBackupEnvelope(
      salt: salt,
      nonce: secretBox.nonce,
      mac: secretBox.mac.bytes,
      cipherText: secretBox.cipherText,
    );
    return envelope.toBytes();
  }

  @visibleForTesting
  static Future<Uint8List> decryptBackupBytes(
    List<int> bytes, {
    required String passphrase,
  }) async {
    final validationMessage = validatePassphrase(passphrase);
    if (validationMessage != null) {
      throw Exception(validationMessage);
    }
    final normalizedPassphrase = passphrase.trim();

    final envelope = _EncryptedBackupEnvelope.fromBytes(bytes);
    final secretKey = await _kdf.deriveKeyFromPassword(
      password: normalizedPassphrase,
      nonce: envelope.salt,
    );

    try {
      final clearBytes = await _cipher.decrypt(
        SecretBox(
          envelope.cipherText,
          nonce: envelope.nonce,
          mac: Mac(envelope.mac),
        ),
        secretKey: secretKey,
      );
      return Uint8List.fromList(clearBytes);
    } on SecretBoxAuthenticationError {
      throw Exception('备份口令错误，或备份文件已损坏。');
    }
  }

  static Future<File> _prepareRestoreSource(
    File sourceFile, {
    required void Function(String tempPath) onPrepared,
    String? passphrase,
  }) async {
    if (!isEncryptedBackupPath(sourceFile.path)) {
      return sourceFile;
    }

    final normalizedPassphrase = _normalizePassphrase(passphrase ?? '');
    if (normalizedPassphrase == null) {
      throw Exception('请输入加密备份口令。');
    }

    final decryptedBytes = await decryptBackupBytes(
      await sourceFile.readAsBytes(),
      passphrase: normalizedPassphrase,
    );
    final tempDir = await _getTemporaryDirectory();
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    final tempPath = p.join(tempDir.path, buildBackupFileName(DateTime.now()));
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(decryptedBytes, flush: true);
    onPrepared(tempPath);
    return tempFile;
  }

  static Future<void> _validateBackupFile(File file) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final header = await raf.read(16);
      if (header.length < 16 ||
          !String.fromCharCodes(header).startsWith('SQLite format 3')) {
        throw Exception('选择的文件不是有效的数据库备份。');
      }
    } finally {
      await raf.close();
    }

    final db = await openDatabase(
      file.path,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final integrityRows = await db.rawQuery('PRAGMA integrity_check(1)');
      final integrityValue = integrityRows.isEmpty
          ? null
          : integrityRows.first.values.firstOrNull?.toString().toLowerCase();
      if (integrityValue != 'ok') {
        throw Exception('备份文件已损坏或未完整保存，无法恢复。');
      }

      final versionRows = await db.rawQuery('PRAGMA user_version');
      final schemaVersion = Sqflite.firstIntValue(versionRows) ?? 0;
      if (schemaVersion < 1 || schemaVersion > DatabaseHelper.databaseVersion) {
        throw Exception('该备份文件版本与当前应用不兼容，无法恢复。');
      }

      final tableRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tableRows
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();
      const requiredTables = {
        'students',
        'attendance',
        'payments',
        'class_templates',
        'settings',
      };
      if (!tableNames.containsAll(requiredTables)) {
        throw Exception('备份文件缺少必要数据表，无法恢复当前应用数据。');
      }
    } finally {
      await db.close();
    }
  }

  static bool _isSupportedRestoreFile(String filePath) {
    final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    return _restoreExtensions.contains(extension);
  }

  static bool _isSnapshotBackupFile(String filePath) {
    final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    return _snapshotExtensions.contains(extension);
  }

  static Future<Directory> _resolveBackupDirectory() async {
    final baseDir = await _getApplicationSupportDirectory();
    final currentDir = Directory(p.join(baseDir.path, _backupDirectoryName));
    if (!await currentDir.exists()) {
      await currentDir.create(recursive: true);
    }

    await _migrateLegacyDirectories(currentDir);
    return currentDir;
  }

  static Future<void> _migrateLegacyDirectories(Directory targetDir) async {
    final supportDir = await _getApplicationSupportDirectory();
    final tempDir = await _getTemporaryDirectory();
    final legacyDirs = <Directory>[
      Directory(p.join(supportDir.path, _legacyBackupDirectoryName)),
      Directory(p.join(tempDir.path, _backupDirectoryName)),
      Directory(p.join(tempDir.path, _legacyBackupDirectoryName)),
    ];

    if (Platform.isAndroid) {
      final externalDir =
          await externalStorageDirectoryResolver?.call() ??
          await getExternalStorageDirectory();
      if (externalDir != null) {
        legacyDirs.addAll([
          Directory(p.join(externalDir.path, _backupDirectoryName)),
          Directory(p.join(externalDir.path, _legacyBackupDirectoryName)),
        ]);
      }
    }

    for (final sourceDir in legacyDirs) {
      if (sourceDir.path == targetDir.path || !await sourceDir.exists()) {
        continue;
      }
      await _copyBackupFiles(sourceDir, targetDir);
    }
  }

  static Future<void> _copyBackupFiles(
    Directory sourceDir,
    Directory targetDir,
  ) async {
    await targetDir.create(recursive: true);
    await for (final entity in sourceDir.list(followLinks: false)) {
      if (entity is! File || !_isSnapshotBackupFile(entity.path)) {
        continue;
      }

      final destinationPath = p.join(targetDir.path, p.basename(entity.path));
      final destinationFile = File(destinationPath);
      if (await destinationFile.exists()) {
        continue;
      }
      await entity.copy(destinationPath);
    }
  }

  static Future<Directory> _getApplicationSupportDirectory() {
    return applicationSupportDirectoryResolver?.call() ??
        getApplicationSupportDirectory();
  }

  static Future<Directory> _getTemporaryDirectory() {
    return temporaryDirectoryResolver?.call() ?? getTemporaryDirectory();
  }

  static String _formatTimestamp(DateTime timestamp) {
    final year = timestamp.year.toString().padLeft(4, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$year-$month-${day}_$hour-$minute-$second';
  }

  static String? _normalizePassphrase(String passphrase) {
    final normalized = passphrase.trim();
    if (normalized.length < _minimumPassphraseLength) {
      return null;
    }
    return normalized;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

class _EncryptedBackupEnvelope {
  final List<int> salt;
  final List<int> nonce;
  final List<int> mac;
  final List<int> cipherText;

  const _EncryptedBackupEnvelope({
    required this.salt,
    required this.nonce,
    required this.mac,
    required this.cipherText,
  });

  Uint8List toBytes() {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': BackupHelper._encryptedBackupFormat,
          'version': BackupHelper._encryptedBackupVersion,
          'algorithm': 'aes-256-gcm',
          'kdf': 'pbkdf2-hmac-sha256',
          'iterations': BackupHelper._pbkdf2Iterations,
          'salt': base64Encode(salt),
          'nonce': base64Encode(nonce),
          'mac': base64Encode(mac),
          'ciphertext': base64Encode(cipherText),
        }),
      ),
    );
  }

  factory _EncryptedBackupEnvelope.fromBytes(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      if (decoded['format'] != BackupHelper._encryptedBackupFormat ||
          decoded['version'] != BackupHelper._encryptedBackupVersion) {
        throw const FormatException();
      }

      return _EncryptedBackupEnvelope(
        salt: base64Decode(decoded['salt'] as String),
        nonce: base64Decode(decoded['nonce'] as String),
        mac: base64Decode(decoded['mac'] as String),
        cipherText: base64Decode(decoded['ciphertext'] as String),
      );
    } on FormatException {
      throw Exception('选择的文件不是有效的加密备份。');
    } on TypeError {
      throw Exception('选择的文件不是有效的加密备份。');
    }
  }
}
