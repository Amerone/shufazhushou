import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

class BackupBundle {
  final Uint8List databaseBytes;
  final Map<String, Uint8List> artworkFiles;
  final Map<String, String> sensitiveSettings;

  const BackupBundle({
    required this.databaseBytes,
    required this.artworkFiles,
    required this.sensitiveSettings,
  });
}

class BackupBundleCodec {
  static const format = 'moyun_backup_bundle';
  static const version = 1;

  const BackupBundleCodec();

  Uint8List encode({
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
          'format': format,
          'version': version,
          'database': base64Encode(databaseBytes),
          'artwork_files': normalizedArtworkFiles,
          'sensitive_settings': sensitiveSettings,
        }),
      ),
    );
  }

  BackupBundle? tryDecode(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      if (decoded['format'] != format || decoded['version'] != version) {
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

      return BackupBundle(
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
}
