import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../services/attendance_artwork_storage_service.dart';
import '../services/backup/backup_bundle_codec.dart';
import '../services/backup/backup_crypto_codec.dart';
import '../services/backup/backup_file_naming.dart';
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
  static const encryptedBackupExtension =
      BackupFileNaming.encryptedBackupExtension;
  static const minimumPassphraseLength =
      BackupCryptoCodec.minimumPassphraseLength;
  static const _artworkSnapshotDirectorySuffix = '.artworks';
  static const _sensitiveSettingsSnapshotSuffix = '.sensitive.json';
  static const _fileNaming = BackupFileNaming();
  static const _bundleCodec = BackupBundleCodec();
  static final _cryptoCodec = BackupCryptoCodec();

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

  @visibleForTesting
  static Future<String> Function()? databasePathResolver;

  @visibleForTesting
  static Future<void> Function()? databaseSnapshotPreparer;

  @visibleForTesting
  static Future<void> Function(File file)? backupFileValidator;

  @visibleForTesting
  static Future<void> Function({
    required bool includesArtworkSnapshot,
    Directory? artworkDirectory,
  })?
  restoredArtworkSnapshotApplier;

  static Future<String> backup({DateTime? at}) async {
    await _prepareDatabaseSnapshot();
    final dbPath = await _resolveDatabasePath();
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
      throw Exception(
        '\u672A\u627E\u5230\u5F85\u5BFC\u51FA\u7684\u5907\u4EFD\u6587\u4EF6\uFF0C\u8BF7\u91CD\u65B0\u751F\u6210\u540E\u518D\u8BD5\u3002',
      );
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
      allowedExtensions: _fileNaming.supportedRestoreExtensions(),
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
        '\u8BF7\u9009\u62E9 .db\u3001.sqlite\u3001.sqlite3 \u6216 .$encryptedBackupExtension \u5907\u4EFD\u6587\u4EF6\u3002',
      );
    }

    final sourceFile = File(normalizedPath);
    if (!await sourceFile.exists()) {
      throw Exception(
        '\u672A\u627E\u5230\u5907\u4EFD\u6587\u4EF6\uFF0C\u8BF7\u91CD\u65B0\u9009\u62E9\u3002',
      );
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

      final dbPath = await _resolveDatabasePath();
      final dbDir = Directory(p.dirname(dbPath));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      await _prepareDatabaseSnapshot();
      final rollbackSnapshot = await _captureRestoreRollbackSnapshot(dbPath);
      try {
        await applyRestoredSensitiveSettings(restoreSource.sensitiveSettings);
        await applyRestoredArtworkSnapshot(
          includesArtworkSnapshot: restoreSource.includesArtworkSnapshot,
          artworkDirectory: restoreSource.artworkDirectory,
        );
        await _replaceDatabaseFile(dbPath, restoreSource.databaseFile);
        DatabaseHelper.instance.resetForRestore();
      } catch (error, stackTrace) {
        await _tryRollbackRestore(dbPath, rollbackSnapshot);
        Error.throwWithStackTrace(error, stackTrace);
      }
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
    return _fileNaming.buildPlainFileName(at ?? DateTime.now());
  }

  @visibleForTesting
  static String buildEncryptedBackupFileName([DateTime? at]) {
    return _fileNaming.buildEncryptedFileName(at ?? DateTime.now());
  }

  static bool hasSupportedBackupExtension(String filePath) {
    return _isSupportedRestoreFile(filePath);
  }

  static bool isEncryptedBackupPath(String filePath) {
    return _fileNaming.isEncryptedPath(filePath);
  }

  static String? validatePassphrase(String passphrase, {String? confirmation}) {
    return _cryptoCodec.validatePassphrase(
      passphrase,
      confirmation: confirmation,
    );
  }

  static Future<String> backupDirectoryPath() async {
    final backupDir = await _resolveBackupDirectory();
    return backupDir.path;
  }

  @visibleForTesting
  static Future<Uint8List> encryptBackupBytes(
    List<int> bytes, {
    required String passphrase,
  }) {
    return _cryptoCodec.encrypt(bytes, passphrase: passphrase);
  }

  @visibleForTesting
  static Future<Uint8List> decryptBackupBytes(
    List<int> bytes, {
    required String passphrase,
  }) {
    return _cryptoCodec.decrypt(bytes, passphrase: passphrase);
  }

  @visibleForTesting
  static Uint8List buildBackupBundleBytes({
    required List<int> databaseBytes,
    Map<String, List<int>> artworkFiles = const <String, List<int>>{},
    Map<String, String> sensitiveSettings = const <String, String>{},
  }) {
    return _bundleCodec.encode(
      databaseBytes: databaseBytes,
      artworkFiles: artworkFiles,
      sensitiveSettings: sensitiveSettings,
    );
  }

  @visibleForTesting
  static ({
    Uint8List databaseBytes,
    Map<String, Uint8List> artworkFiles,
    Map<String, String> sensitiveSettings,
  })?
  tryDecodeBackupBundleBytes(List<int> bytes) {
    final decoded = _bundleCodec.tryDecode(bytes);
    if (decoded == null) {
      return null;
    }

    return (
      databaseBytes: decoded.databaseBytes,
      artworkFiles: decoded.artworkFiles,
      sensitiveSettings: decoded.sensitiveSettings,
    );
  }

  @visibleForTesting
  static bool payloadIncludesArtworkSnapshot(List<int> bytes) {
    return _bundleCodec.tryDecode(bytes) != null;
  }

  @visibleForTesting
  static Future<void> applyRestoredArtworkSnapshot({
    required bool includesArtworkSnapshot,
    Directory? artworkDirectory,
  }) async {
    if (restoredArtworkSnapshotApplier != null) {
      await restoredArtworkSnapshotApplier!(
        includesArtworkSnapshot: includesArtworkSnapshot,
        artworkDirectory: artworkDirectory,
      );
      return;
    }

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

    final normalizedPassphrase = passphrase?.trim() ?? '';
    if (normalizedPassphrase.length < minimumPassphraseLength) {
      throw Exception(
        '\u8BF7\u8F93\u5165\u52A0\u5BC6\u5907\u4EFD\u53E3\u4EE4\u3002',
      );
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
    final decodedBundle = _bundleCodec.tryDecode(decryptedBytes);
    if (decodedBundle == null) {
      await tempFile.writeAsBytes(decryptedBytes, flush: true);
      onPreparedDatabase(tempPath);
      return _PreparedRestoreSource(
        databaseFile: tempFile,
        includesArtworkSnapshot: false,
        sensitiveSettings: <String, String>{},
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
    if (backupFileValidator != null) {
      await backupFileValidator!(file);
      return;
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      final header = await raf.read(16);
      if (header.length < 16 ||
          !String.fromCharCodes(header).startsWith('SQLite format 3')) {
        throw Exception(
          '\u9009\u62E9\u7684\u6587\u4EF6\u4E0D\u662F\u6709\u6548\u7684\u6570\u636E\u5E93\u5907\u4EFD\u3002',
        );
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
        throw Exception(
          '\u5907\u4EFD\u6587\u4EF6\u5DF2\u635F\u574F\u6216\u672A\u5B8C\u6574\u4FDD\u5B58\uFF0C\u65E0\u6CD5\u6062\u590D\u3002',
        );
      }

      final versionRows = await db.rawQuery('PRAGMA user_version');
      final schemaVersion = Sqflite.firstIntValue(versionRows) ?? 0;
      if (schemaVersion < 1 || schemaVersion > DatabaseHelper.databaseVersion) {
        throw Exception(
          '\u8BE5\u5907\u4EFD\u6587\u4EF6\u7248\u672C\u4E0E\u5F53\u524D\u5E94\u7528\u4E0D\u517C\u5BB9\uFF0C\u65E0\u6CD5\u6062\u590D\u3002',
        );
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
        throw Exception(
          '\u5907\u4EFD\u6587\u4EF6\u7F3A\u5C11\u5FC5\u8981\u6570\u636E\u8868\uFF0C\u65E0\u6CD5\u6062\u590D\u5F53\u524D\u5E94\u7528\u6570\u636E\u3002',
        );
      }
    } finally {
      await db.close();
    }
  }

  static bool _isSupportedRestoreFile(String filePath) {
    return _fileNaming.hasSupportedExtension(filePath);
  }

  static bool _isSnapshotBackupFile(String filePath) {
    return _fileNaming.isSnapshotPath(filePath);
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

  static Future<String> _resolveDatabasePath() {
    return databasePathResolver?.call() ?? DatabaseHelper.resolveDatabasePath();
  }

  static Future<void> _prepareDatabaseSnapshot() {
    return databaseSnapshotPreparer?.call() ??
        DatabaseHelper.instance.prepareForFileSnapshot();
  }

  static Future<Map<String, String>> _readSensitiveSettings() async {
    if (sensitiveSettingsReader != null) {
      return sensitiveSettingsReader!();
    }
    return SensitiveSettingsStore().readAll();
  }

  static Future<_RestoreRollbackSnapshot> _captureRestoreRollbackSnapshot(
    String dbPath,
  ) async {
    final currentDatabase = File(dbPath);
    final databaseBytes = await currentDatabase.exists()
        ? await currentDatabase.readAsBytes()
        : null;
    final artworkFiles = await const AttendanceArtworkStorageService()
        .readArtworkSnapshot();
    final sensitiveSettings = await _readSensitiveSettings();
    return _RestoreRollbackSnapshot(
      databaseBytes: databaseBytes,
      artworkFiles: artworkFiles,
      sensitiveSettings: sensitiveSettings,
    );
  }

  static Future<void> _replaceDatabaseFile(String dbPath, File source) async {
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final sidecar = File('$dbPath$suffix');
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
    await source.copy(dbPath);
  }

  static Future<void> _tryRollbackRestore(
    String dbPath,
    _RestoreRollbackSnapshot snapshot,
  ) async {
    try {
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final sidecar = File('$dbPath$suffix');
        if (await sidecar.exists()) {
          await sidecar.delete();
        }
      }

      final databaseFile = File(dbPath);
      if (snapshot.databaseBytes == null) {
        if (await databaseFile.exists()) {
          await databaseFile.delete();
        }
      } else {
        await databaseFile.writeAsBytes(snapshot.databaseBytes!, flush: true);
      }
      await const AttendanceArtworkStorageService().restoreArtworkSnapshot(
        snapshot.artworkFiles,
      );
      await applyRestoredSensitiveSettings(snapshot.sensitiveSettings);
      DatabaseHelper.instance.resetForRestore();
    } catch (error) {
      debugPrint('Failed to rollback restore: $error');
    }
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

class _RestoreRollbackSnapshot {
  final Uint8List? databaseBytes;
  final Map<String, Uint8List> artworkFiles;
  final Map<String, String> sensitiveSettings;

  const _RestoreRollbackSnapshot({
    required this.databaseBytes,
    required this.artworkFiles,
    required this.sensitiveSettings,
  });
}
