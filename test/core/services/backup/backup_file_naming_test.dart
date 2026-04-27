import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/backup/backup_file_naming.dart';

void main() {
  const naming = BackupFileNaming();

  test('builds readable timestamped file names for plain backups', () {
    expect(
      naming.buildPlainFileName(DateTime(2026, 4, 1, 9, 5, 7)),
      'moyun_backup_2026-04-01_09-05-07.db',
    );
  });

  test('builds readable timestamped file names for encrypted backups', () {
    expect(
      naming.buildEncryptedFileName(DateTime(2026, 4, 1, 9, 5, 7)),
      'moyun_backup_2026-04-01_09-05-07.moyunbak',
    );
  });

  test(
    'supported extension checks preserve plain and encrypted restore inputs',
    () {
      expect(naming.hasSupportedExtension('/tmp/moyun_backup.db'), isTrue);
      expect(naming.hasSupportedExtension('/tmp/moyun_backup.sqlite'), isTrue);
      expect(naming.hasSupportedExtension('/tmp/moyun_backup.sqlite3'), isTrue);
      expect(
        naming.hasSupportedExtension('/tmp/moyun_backup.moyunbak'),
        isTrue,
      );
      expect(naming.hasSupportedExtension('/tmp/MOYUN_BACKUP.SQLITE3'), isTrue);
      expect(naming.hasSupportedExtension('/tmp/moyun_backup.zip'), isFalse);
    },
  );

  test('distinguishes encrypted backups from plain snapshot backups', () {
    expect(naming.isEncryptedPath('/tmp/moyun_backup.moyunbak'), isTrue);
    expect(naming.isEncryptedPath('/tmp/moyun_backup.db'), isFalse);
    expect(naming.isSnapshotPath('/tmp/moyun_backup.sqlite'), isTrue);
    expect(naming.isSnapshotPath('/tmp/moyun_backup.moyunbak'), isFalse);
  });
}
