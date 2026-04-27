import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/backup/backup_file_naming.dart';

void main() {
  test('database design document matches runtime version and indexes', () {
    final helper = File(
      'lib/core/database/database_helper.dart',
    ).readAsStringSync();
    final docs = File('docs/database-design.md').readAsStringSync();

    final versionMatch = RegExp(
      r'databaseVersion\s*=\s*(\d+)',
    ).firstMatch(helper);

    expect(versionMatch, isNotNull);

    final version = versionMatch!.group(1)!;
    expect(docs, contains('当前版本：`$version`'));

    final indexMatches = RegExp(
      r'CREATE INDEX IF NOT EXISTS ([a-zA-Z0-9_]+)',
    ).allMatches(helper);

    final indexNames = indexMatches
        .map((match) => match.group(1))
        .whereType<String>()
        .toSet();

    expect(indexNames, isNotEmpty);
    for (final indexName in indexNames) {
      expect(docs, contains(indexName));
    }
  });

  test('database design document matches runtime backup naming', () {
    final docs = File('docs/database-design.md').readAsStringSync();
    const naming = BackupFileNaming();
    final sampleAt = DateTime(2026, 4, 27, 9, 8, 7);

    expect(docs, contains(BackupFileNaming.backupFilePrefix));
    expect(docs, contains(naming.buildPlainFileName(sampleAt)));
    expect(docs, contains(naming.buildEncryptedFileName(sampleAt)));

    for (final extension in BackupFileNaming.restoreExtensions) {
      expect(docs, contains('.$extension'));
    }
  });
}
