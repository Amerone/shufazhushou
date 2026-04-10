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
import '../services/attendance_artwork_storage_service.dart';
import '../services/sensitive_settings_store.dart';

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
  static const _backupBundleFormat = 'moyun_backup_bundle';
  static const _backupBundleVersion = 1;
  static const _artworkSnapshotDirectorySuffix = '.artworks';
  static const _sensitiveSettingsSnapshotSuffix = '.sensitive.json';
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

  @visibleForTesting
  static Future<Map<String, String>> Function()? sensitiveSettingsReader;

  @visibleForTesting
  static Future<void> Function(Map<String, String>)? sensitiveSettingsWriter;

  static Future<String> backup({DateTime? at}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}

    final dbPath = await DatabaseHelper.resolveDatabasePath();
    final backupDir = await _resolveBackupDirectory();
    final destination = p.join(backupDir.path, buildBackupFileName(at));
    await File(dbPath).copy(destination);
    await _writeArtworkSnapshot(destination);
    await _writeSensitiveSettingsSnapshot(destination);
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
      await _buildBackupPayload(rawBackupPath),
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
          sizeInBytes: await _calculateSnapshotBackupSize(entity, stat.size),
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
    String? decryptedArtworkTempDirPath;
    try {
      final restoreSource = await _prepareRestoreSource(
        sourceFile,
        passphrase: passphrase,
        onPreparedDatabase: (tempPath) => decryptedTempPath = tempPath,
        onPreparedArtworkDirectory: (tempPath) =>
            decryptedArtworkTempDirPath = tempPath,
      );
      await _validateBackupFile(restoreSource.databaseFile);

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

      await restoreSource.databaseFile.copy(dbPath);
      await applyRestoredArtworkSnapshot(
        includesArtworkSnapshot: restoreSource.includesArtworkSnapshot,
        artworkDirectory: restoreSource.artworkDirectory,
      );
      await applyRestoredSensitiveSettings(restoreSource.sensitiveSettings);
      return true;
    } finally {
      if (decryptedTempPath != null) {
        final tempFile = File(decryptedTempPath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
      if (decryptedArtworkTempDirPath != null) {
        final tempDirectory = Directory(decryptedArtworkTempDirPath!);
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
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

  @visibleForTesting
  static Uint8List buildBackupBundleBytes({
    required List<int> databaseBytes,
    Map<String, List<int>> artworkFiles = const <String, List<int>>{},
    Map<String, String> sensitiveSettings = const <String, String>{},
  }) {
    final normalizedArtworkFiles = <String, String>{};
    for (final entry in artworkFiles.entries) {
      normalizedArtworkFiles[p.basename(entry.key)] = base64Encode(entry.value);
    }

    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': _backupBundleFormat,
          'version': _backupBundleVersion,
          'database': base64Encode(databaseBytes),
          'artwork_files': normalizedArtworkFiles,
          'sensitive_settings': sensitiveSettings,
        }),
      ),
    );
  }

  @visibleForTesting
  static ({
    Uint8List databaseBytes,
    Map<String, Uint8List> artworkFiles,
    Map<String, String> sensitiveSettings,
  })?
  tryDecodeBackupBundleBytes(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      if (decoded['format'] != _backupBundleFormat ||
          decoded['version'] != _backupBundleVersion) {
        return null;
      }

      final rawArtworkFiles =
          decoded['artwork_files'] as Map<String, dynamic>? ?? const {};
      final rawSensitiveSettings =
          decoded['sensitive_settings'] as Map<String, dynamic>? ?? const {};
      final artworkFiles = <String, Uint8List>{};
      for (final entry in rawArtworkFiles.entries) {
        artworkFiles[p.basename(entry.key)] = Uint8List.fromList(
          base64Decode(entry.value as String),
        );
      }
      final sensitiveSettings = <String, String>{};
      for (final entry in rawSensitiveSettings.entries) {
        final key = entry.key.trim();
        final value = (entry.value as String).trim();
        if (key.isEmpty || value.isEmpty) continue;
        sensitiveSettings[key] = value;
      }

      return (
        databaseBytes: Uint8List.fromList(
          base64Decode(decoded['database'] as String),
        ),
        artworkFiles: artworkFiles,
        sensitiveSettings: sensitiveSettings,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @visibleForTesting
  static bool payloadIncludesArtworkSnapshot(List<int> bytes) {
    return tryDecodeBackupBundleBytes(bytes) != null;
  }

  @visibleForTesting
  static Future<void> applyRestoredArtworkSnapshot({
    required bool includesArtworkSnapshot,
    Directory? artworkDirectory,
  }) async {
    const storage = AttendanceArtworkStorageService();
    if (includesArtworkSnapshot) {
      await storage.restoreArtworkSnapshotFrom(artworkDirectory!);
      return;
    }
    await storage.clearArtworkDirectory();
  }

  @visibleForTesting
  static Future<void> applyRestoredSensitiveSettings(
    Map<String, String> settings,
  ) async {
    if (sensitiveSettingsWriter != null) {
      await sensitiveSettingsWriter!(settings);
      return;
    }

    final store = SensitiveSettingsStore();
    await store.clearAll();
    for (final entry in settings.entries) {
      await store.set(entry.key, entry.value);
    }
  }

  static Future<_PreparedRestoreSource> _prepareRestoreSource(
    File sourceFile, {
    required void Function(String tempPath) onPreparedDatabase,
    required void Function(String tempPath) onPreparedArtworkDirectory,
    String? passphrase,
  }) async {
    if (!isEncryptedBackupPath(sourceFile.path)) {
      final artworkDirectory = await _existingArtworkSnapshotDirectory(
        sourceFile.path,
      );
      final sensitiveSettings = await _readSensitiveSettingsSnapshot(
        sourceFile.path,
      );
      return _PreparedRestoreSource(
        databaseFile: sourceFile,
        artworkDirectory: artworkDirectory,
        includesArtworkSnapshot: artworkDirectory != null,
        sensitiveSettings: sensitiveSettings,
      );
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
    final decodedBundle = tryDecodeBackupBundleBytes(decryptedBytes);
    if (decodedBundle == null) {
      await tempFile.writeAsBytes(decryptedBytes, flush: true);
      onPreparedDatabase(tempPath);
      return _PreparedRestoreSource(
        databaseFile: tempFile,
        includesArtworkSnapshot: false,
        sensitiveSettings: const <String, String>{},
      );
    }

    await tempFile.writeAsBytes(decodedBundle.databaseBytes, flush: true);
    onPreparedDatabase(tempPath);

    final artworkTempDirectory = _buildArtworkSnapshotDirectory(tempPath);
    await _writeArtworkSnapshotDirectory(
      artworkTempDirectory,
      decodedBundle.artworkFiles,
    );
    onPreparedArtworkDirectory(artworkTempDirectory.path);

    return _PreparedRestoreSource(
      databaseFile: tempFile,
      artworkDirectory: artworkTempDirectory,
      includesArtworkSnapshot: true,
      sensitiveSettings: decodedBundle.sensitiveSettings,
    );
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
      if (!await destinationFile.exists()) {
        await entity.copy(destinationPath);
      }

      final sourceSensitiveSettingsFile = _buildSensitiveSettingsSnapshotFile(
        entity.path,
      );
      if (await sourceSensitiveSettingsFile.exists()) {
        final destinationSensitiveSettingsFile =
            _buildSensitiveSettingsSnapshotFile(destinationPath);
        if (!await destinationSensitiveSettingsFile.exists()) {
          await sourceSensitiveSettingsFile.copy(
            destinationSensitiveSettingsFile.path,
          );
        }
      }

      final sourceArtworkDir = _buildArtworkSnapshotDirectory(entity.path);
      if (!await sourceArtworkDir.exists()) {
        continue;
      }

      final targetArtworkDir = _buildArtworkSnapshotDirectory(destinationPath);
      if (await targetArtworkDir.exists()) {
        continue;
      }
      await _writeArtworkSnapshotDirectory(
        targetArtworkDir,
        await _readArtworkSnapshotDirectory(sourceArtworkDir),
      );
    }
  }

  static Future<int> _calculateSnapshotBackupSize(
    File databaseFile,
    int databaseSize,
  ) async {
    var total = databaseSize;
    final artworkDirectory = _buildArtworkSnapshotDirectory(databaseFile.path);
    if (await artworkDirectory.exists()) {
      total += await _calculateDirectorySize(artworkDirectory);
    }

    final sensitiveSettingsFile = _buildSensitiveSettingsSnapshotFile(
      databaseFile.path,
    );
    if (await sensitiveSettingsFile.exists()) {
      total += await sensitiveSettingsFile.length();
    }

    return total;
  }

  static Future<int> _calculateDirectorySize(Directory directory) async {
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      total += await entity.length();
    }
    return total;
  }

  static Future<Uint8List> _buildBackupPayload(String backupPath) async {
    final databaseBytes = await File(backupPath).readAsBytes();
    final artworkFiles = await _readArtworkSnapshotDirectory(
      _buildArtworkSnapshotDirectory(backupPath),
    );
    final sensitiveSettings = await _readSensitiveSettingsSnapshot(backupPath);
    return buildBackupBundleBytes(
      databaseBytes: databaseBytes,
      artworkFiles: artworkFiles,
      sensitiveSettings: sensitiveSettings,
    );
  }

  static Future<void> _writeArtworkSnapshot(String backupPath) async {
    await const AttendanceArtworkStorageService().copyArtworkSnapshotTo(
      _buildArtworkSnapshotDirectory(backupPath),
    );
  }

  static Future<void> _writeSensitiveSettingsSnapshot(String backupPath) async {
    final sensitiveSettings = await _readSensitiveSettings();
    final snapshotFile = _buildSensitiveSettingsSnapshotFile(backupPath);
    if (sensitiveSettings.isEmpty) {
      if (await snapshotFile.exists()) {
        await snapshotFile.delete();
      }
      return;
    }

    await snapshotFile.writeAsString(
      jsonEncode(sensitiveSettings),
      flush: true,
    );
  }

  static Directory _buildArtworkSnapshotDirectory(String backupPath) {
    return Directory('$backupPath$_artworkSnapshotDirectorySuffix');
  }

  static File _buildSensitiveSettingsSnapshotFile(String backupPath) {
    return File('$backupPath$_sensitiveSettingsSnapshotSuffix');
  }

  static Future<Directory?> _existingArtworkSnapshotDirectory(
    String backupPath,
  ) async {
    final snapshotDirectory = _buildArtworkSnapshotDirectory(backupPath);
    if (!await snapshotDirectory.exists()) {
      return null;
    }
    return snapshotDirectory;
  }

  static Future<Map<String, Uint8List>> _readArtworkSnapshotDirectory(
    Directory snapshotDirectory,
  ) async {
    if (!await snapshotDirectory.exists()) {
      return const <String, Uint8List>{};
    }

    final files = <String, Uint8List>{};
    await for (final entity in snapshotDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      files[p.basename(entity.path)] = await entity.readAsBytes();
    }
    return files;
  }

  static Future<Map<String, String>> _readSensitiveSettingsSnapshot(
    String backupPath,
  ) async {
    final snapshotFile = _buildSensitiveSettingsSnapshotFile(backupPath);
    if (!await snapshotFile.exists()) {
      return const <String, String>{};
    }

    try {
      final decoded = jsonDecode(await snapshotFile.readAsString());
      if (decoded is! Map) {
        return const <String, String>{};
      }

      final settings = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! String) continue;
        final trimmedKey = key.trim();
        final trimmedValue = value.trim();
        if (trimmedKey.isEmpty || trimmedValue.isEmpty) continue;
        settings[trimmedKey] = trimmedValue;
      }
      return settings;
    } on FormatException {
      return const <String, String>{};
    } on FileSystemException {
      return const <String, String>{};
    }
  }

  static Future<void> _writeArtworkSnapshotDirectory(
    Directory snapshotDirectory,
    Map<String, Uint8List> files,
  ) async {
    if (await snapshotDirectory.exists()) {
      await snapshotDirectory.delete(recursive: true);
    }
    await snapshotDirectory.create(recursive: true);

    for (final entry in files.entries) {
      final targetFile = File(p.join(snapshotDirectory.path, entry.key));
      await targetFile.writeAsBytes(entry.value, flush: true);
    }
  }

  static Future<Directory> _getApplicationSupportDirectory() {
    return applicationSupportDirectoryResolver?.call() ??
        getApplicationSupportDirectory();
  }

  static Future<Directory> _getTemporaryDirectory() {
    return temporaryDirectoryResolver?.call() ?? getTemporaryDirectory();
  }

  static Future<Map<String, String>> _readSensitiveSettings() async {
    if (sensitiveSettingsReader != null) {
      return sensitiveSettingsReader!();
    }
    return SensitiveSettingsStore().readAll();
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

class _PreparedRestoreSource {
  final File databaseFile;
  final Directory? artworkDirectory;
  final bool includesArtworkSnapshot;
  final Map<String, String> sensitiveSettings;

  const _PreparedRestoreSource({
    required this.databaseFile,
    this.artworkDirectory,
    required this.includesArtworkSnapshot,
    this.sensitiveSettings = const <String, String>{},
  });
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
