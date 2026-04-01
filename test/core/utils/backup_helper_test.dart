import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/utils/backup_helper.dart';

void main() {
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
}
