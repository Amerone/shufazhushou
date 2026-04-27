import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/backup/backup_crypto_codec.dart';

void main() {
  late BackupCryptoCodec codec;

  setUp(() {
    codec = BackupCryptoCodec();
  });

  test('validatePassphrase enforces current minimum length and confirmation', () {
    expect(
      codec.validatePassphrase('1234567'),
      '\u5907\u4efd\u53e3\u4ee4\u81f3\u5c11\u9700\u8981 8 \u4e2a\u5b57\u7b26\u3002',
    );
    expect(
      codec.validatePassphrase('12345678', confirmation: '12345679'),
      '\u4e24\u6b21\u8f93\u5165\u7684\u53e3\u4ee4\u4e0d\u4e00\u81f4\u3002',
    );
    expect(
      codec.validatePassphrase('12345678', confirmation: '12345678'),
      isNull,
    );
  });

  test('encrypt and decrypt round-trip plain data', () async {
    final plainBytes = Uint8List.fromList(
      'SQLite format 3 sample payload'.codeUnits,
    );

    final encryptedBytes = await codec.encrypt(
      plainBytes,
      passphrase: 'backup123',
    );
    final decryptedBytes = await codec.decrypt(
      encryptedBytes,
      passphrase: 'backup123',
    );

    expect(encryptedBytes, isNot(equals(plainBytes)));
    expect(decryptedBytes, plainBytes);
  });

  test('encrypt preserves encrypted backup envelope schema', () async {
    final encryptedBytes = await codec.encrypt(
      Uint8List.fromList('SQLite format 3 sample payload'.codeUnits),
      passphrase: 'backup123',
    );
    final envelope =
        jsonDecode(utf8.decode(encryptedBytes)) as Map<String, dynamic>;

    expect(envelope['format'], BackupCryptoCodec.encryptedBackupFormat);
    expect(envelope['version'], BackupCryptoCodec.encryptedBackupVersion);
    expect(envelope['algorithm'], 'aes-256-gcm');
    expect(envelope['kdf'], 'pbkdf2-hmac-sha256');
    expect(envelope['iterations'], BackupCryptoCodec.pbkdf2Iterations);
    expect(envelope['salt'], isA<String>());
    expect(envelope['nonce'], isA<String>());
    expect(envelope['mac'], isA<String>());
    expect(envelope['ciphertext'], isA<String>());
  });

  test(
    'decrypt rejects wrong passphrase and malformed encrypted payload',
    () async {
      final encryptedBytes = await codec.encrypt(
        Uint8List.fromList('SQLite format 3 sample payload'.codeUnits),
        passphrase: 'backup123',
      );

      await expectLater(
        () => codec.decrypt(encryptedBytes, passphrase: 'wrong123'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains(
              '\u5907\u4efd\u53e3\u4ee4\u9519\u8bef\uff0c\u6216\u5907\u4efd\u6587\u4ef6\u5df2\u635f\u574f\u3002',
            ),
          ),
        ),
      );

      await expectLater(
        () => codec.decrypt(
          Uint8List.fromList(utf8.encode('{"format":"wrong"}')),
          passphrase: 'backup123',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains(
              '\u9009\u62e9\u7684\u6587\u4ef6\u4e0d\u662f\u6709\u6548\u7684\u52a0\u5bc6\u5907\u4efd\u3002',
            ),
          ),
        ),
      );
    },
  );
}
