import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/backup/backup_bundle_codec.dart';

void main() {
  const codec = BackupBundleCodec();

  test('encode and decode preserve database bytes and sidecar snapshots', () {
    final bundleBytes = codec.encode(
      databaseBytes: Uint8List.fromList(
        'SQLite format 3 sample payload'.codeUnits,
      ),
      artworkFiles: const {
        'calligraphy-1.jpg': [1, 2, 3],
        'nested/calligraphy-2.jpg': [4, 5, 6],
      },
      sensitiveSettings: const {'qwen_api_key': 'secret-key'},
    );

    final decoded = codec.tryDecode(bundleBytes);

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
  });

  test('decode trims setting values and drops empty keys or values', () {
    final bundleBytes = codec.encode(
      databaseBytes: const [1, 2, 3],
      sensitiveSettings: const {
        ' keep ': ' value ',
        '': 'ignored',
        'ignored': '',
      },
    );

    final decoded = codec.tryDecode(bundleBytes);

    expect(decoded, isNotNull);
    expect(decoded!.sensitiveSettings, {'keep': 'value'});
  });

  test('decode returns null for invalid or legacy raw payloads', () {
    expect(
      codec.tryDecode(Uint8List.fromList('SQLite format 3'.codeUnits)),
      isNull,
    );
    expect(codec.tryDecode(Uint8List.fromList(const [1, 2, 3, 4])), isNull);
  });
}
