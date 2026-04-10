import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/attendance_artwork_storage_service.dart';
import 'package:moyun/core/utils/backup_helper.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  const artworkStorage = AttendanceArtworkStorageService();
  Map<String, String> restoredSensitiveSettings = const {};

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('backup-helper-test');
    BackupHelper.applicationSupportDirectoryResolver = () async => tempRoot;
    BackupHelper.temporaryDirectoryResolver = () async => tempRoot;
    BackupHelper.externalStorageDirectoryResolver = () async => null;
    BackupHelper.sensitiveSettingsReader = () async => const {};
    BackupHelper.sensitiveSettingsWriter = (settings) async {
      restoredSensitiveSettings = Map<String, String>.from(settings);
    };
    AttendanceArtworkStorageService.documentsDirectoryResolver = () async =>
        tempRoot;
    restoredSensitiveSettings = const {};
  });

  tearDown(() async {
    BackupHelper.applicationSupportDirectoryResolver = null;
    BackupHelper.temporaryDirectoryResolver = null;
    BackupHelper.externalStorageDirectoryResolver = null;
    BackupHelper.sensitiveSettingsReader = null;
    BackupHelper.sensitiveSettingsWriter = null;
    AttendanceArtworkStorageService.documentsDirectoryResolver = null;
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('buildBackupFileName outputs readable timestamped name', () {
    final fileName = BackupHelper.buildBackupFileName(
      DateTime(2026, 4, 1, 9, 5, 7),
    );

    expect(fileName, 'moyun_backup_2026-04-01_09-05-07.db');
  });

  test('buildEncryptedBackupFileName outputs readable timestamped name', () {
    final fileName = BackupHelper.buildEncryptedBackupFileName(
      DateTime(2026, 4, 1, 9, 5, 7),
    );

    expect(fileName, 'moyun_backup_2026-04-01_09-05-07.moyunbak');
  });

  test('hasSupportedBackupExtension validates plain and encrypted formats', () {
    expect(
      BackupHelper.hasSupportedBackupExtension('/tmp/moyun_backup.db'),
      isTrue,
    );
    expect(
      BackupHelper.hasSupportedBackupExtension('/tmp/moyun_backup.sqlite'),
      isTrue,
    );
    expect(
      BackupHelper.hasSupportedBackupExtension('/tmp/moyun_backup.sqlite3'),
      isTrue,
    );
    expect(
      BackupHelper.hasSupportedBackupExtension('/tmp/moyun_backup.moyunbak'),
      isTrue,
    );
    expect(
      BackupHelper.hasSupportedBackupExtension('/tmp/moyun_backup.zip'),
      isFalse,
    );
  });

  test('validatePassphrase requires minimum length', () {
    expect(BackupHelper.validatePassphrase('1234567'), isNotNull);
    expect(BackupHelper.validatePassphrase('12345678'), isNull);
  });

  test(
    'encryptBackupBytes and decryptBackupBytes round-trip plain data',
    () async {
      final plainBytes = Uint8List.fromList(
        'SQLite format 3 sample payload'.codeUnits,
      );

      final encryptedBytes = await BackupHelper.encryptBackupBytes(
        plainBytes,
        passphrase: 'backup123',
      );
      final decryptedBytes = await BackupHelper.decryptBackupBytes(
        encryptedBytes,
        passphrase: 'backup123',
      );

      expect(encryptedBytes, isNot(equals(plainBytes)));
      expect(decryptedBytes, plainBytes);
    },
  );

  test('decryptBackupBytes rejects wrong passphrase', () async {
    final encryptedBytes = await BackupHelper.encryptBackupBytes(
      Uint8List.fromList('SQLite format 3 sample payload'.codeUnits),
      passphrase: 'backup123',
    );

    await expectLater(
      () => BackupHelper.decryptBackupBytes(
        encryptedBytes,
        passphrase: 'wrong123',
      ),
      throwsException,
    );
  });

  test(
    'backup bundle payload preserves artwork files and sensitive settings',
    () {
      final bundleBytes = BackupHelper.buildBackupBundleBytes(
        databaseBytes: Uint8List.fromList(
          'SQLite format 3 sample payload'.codeUnits,
        ),
        artworkFiles: const {
          'calligraphy-1.jpg': [1, 2, 3],
          'calligraphy-2.jpg': [4, 5, 6],
        },
        sensitiveSettings: const {'qwen_api_key': 'secret-key'},
      );

      final decoded = BackupHelper.tryDecodeBackupBundleBytes(bundleBytes);

      expect(decoded, isNotNull);
      expect(
        decoded!.databaseBytes,
        Uint8List.fromList('SQLite format 3 sample payload'.codeUnits),
      );
      expect(
        decoded.artworkFiles.keys,
        containsAll(<String>['calligraphy-1.jpg', 'calligraphy-2.jpg']),
      );
      expect(
        decoded.artworkFiles['calligraphy-1.jpg'],
        Uint8List.fromList(const [1, 2, 3]),
      );
      expect(
        decoded.artworkFiles['calligraphy-2.jpg'],
        Uint8List.fromList(const [4, 5, 6]),
      );
      expect(decoded.sensitiveSettings, {'qwen_api_key': 'secret-key'});
    },
  );

  test(
    'payloadIncludesArtworkSnapshot distinguishes bundle from legacy raw db payload',
    () {
      final bundleBytes = BackupHelper.buildBackupBundleBytes(
        databaseBytes: Uint8List.fromList(
          'SQLite format 3 sample payload'.codeUnits,
        ),
      );
      final legacyBytes = Uint8List.fromList(
        'SQLite format 3 sample payload'.codeUnits,
      );

      expect(BackupHelper.payloadIncludesArtworkSnapshot(bundleBytes), isTrue);
      expect(BackupHelper.payloadIncludesArtworkSnapshot(legacyBytes), isFalse);
    },
  );

  test('listBackups counts sidecar artwork snapshots in backup size', () async {
    final backupDir = Directory(p.join(tempRoot.path, 'moyun_backups'));
    await backupDir.create(recursive: true);

    final backupFile = File(p.join(backupDir.path, 'moyun_backup_sample.db'));
    await backupFile.writeAsBytes(const [1, 2, 3, 4], flush: true);

    final artworkDir = Directory('${backupFile.path}.artworks');
    await artworkDir.create(recursive: true);
    await File(
      p.join(artworkDir.path, 'piece-a.jpg'),
    ).writeAsBytes(const [5, 6, 7], flush: true);
    await File(
      p.join(artworkDir.path, 'piece-b.jpg'),
    ).writeAsBytes(const [8, 9], flush: true);

    final records = await BackupHelper.listBackups();

    expect(records, hasLength(1));
    expect(records.single.sizeInBytes, 9);
  });

  test(
    'applyRestoredArtworkSnapshot clears stale artwork without snapshot',
    () async {
      final sourceFile = File(p.join(tempRoot.path, 'stale-artwork.jpg'));
      await sourceFile.writeAsBytes(const [1, 2, 3], flush: true);

      final staleArtworkPath = await artworkStorage.replaceArtwork(
        attendanceId: 'attendance-1',
        sourceImagePath: sourceFile.path,
      );

      expect(File(staleArtworkPath).existsSync(), isTrue);

      await BackupHelper.applyRestoredArtworkSnapshot(
        includesArtworkSnapshot: false,
      );

      expect(File(staleArtworkPath).existsSync(), isFalse);
    },
  );

  test(
    'applyRestoredSensitiveSettings replaces sensitive settings snapshot',
    () async {
      await BackupHelper.applyRestoredSensitiveSettings(const {
        'qwen_api_key': 'restored-key',
      });

      expect(restoredSensitiveSettings, {'qwen_api_key': 'restored-key'});

      await BackupHelper.applyRestoredSensitiveSettings(const {});

      expect(restoredSensitiveSettings, isEmpty);
    },
  );
}
