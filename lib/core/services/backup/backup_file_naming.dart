import 'package:path/path.dart' as p;

class BackupFileNaming {
  static const backupFilePrefix = 'moyun_backup';
  static const encryptedBackupExtension = 'moyunbak';
  static const snapshotExtensions = <String>['db', 'sqlite', 'sqlite3'];
  static const restoreExtensions = <String>[
    ...snapshotExtensions,
    encryptedBackupExtension,
  ];

  const BackupFileNaming();

  String buildPlainFileName(DateTime timestamp) {
    return '${backupFilePrefix}_${_formatTimestamp(timestamp)}.db';
  }

  String buildEncryptedFileName(DateTime timestamp) {
    return '${backupFilePrefix}_${_formatTimestamp(timestamp)}.$encryptedBackupExtension';
  }

  bool hasSupportedExtension(String filePath) {
    return restoreExtensions.contains(_normalizedExtension(filePath));
  }

  bool isEncryptedPath(String filePath) {
    return _normalizedExtension(filePath) == encryptedBackupExtension;
  }

  bool isSnapshotPath(String filePath) {
    return snapshotExtensions.contains(_normalizedExtension(filePath));
  }

  List<String> supportedRestoreExtensions() {
    return restoreExtensions;
  }

  String _normalizedExtension(String filePath) {
    return p.extension(filePath).toLowerCase().replaceFirst('.', '');
  }

  String _formatTimestamp(DateTime timestamp) {
    final year = timestamp.year.toString().padLeft(4, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$year-$month-${day}_$hour-$minute-$second';
  }
}
