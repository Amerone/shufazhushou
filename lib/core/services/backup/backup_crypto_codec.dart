import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupCryptoCodec {
  static const minimumPassphraseLength = 8;
  static const encryptedBackupFormat = 'moyun_encrypted_backup';
  static const encryptedBackupVersion = 1;
  static const pbkdf2Iterations = 120000;
  static const _kdfSaltLength = 16;
  static const _gcmNonceLength = 12;
  static const _invalidEncryptedBackupMessage =
      '\u9009\u62e9\u7684\u6587\u4ef6\u4e0d\u662f\u6709\u6548\u7684\u52a0\u5bc6\u5907\u4efd\u3002';
  static const _passphraseMismatchMessage =
      '\u4e24\u6b21\u8f93\u5165\u7684\u53e3\u4ee4\u4e0d\u4e00\u81f4\u3002';
  static const _wrongPassphraseMessage =
      '\u5907\u4efd\u53e3\u4ee4\u9519\u8bef\uff0c\u6216\u5907\u4efd\u6587\u4ef6\u5df2\u635f\u574f\u3002';

  static final Cipher _defaultCipher = AesGcm.with256bits();
  static final Pbkdf2 _defaultKdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: pbkdf2Iterations,
    bits: 256,
  );

  final Cipher _cipher;
  final Pbkdf2 _kdf;
  final Uint8List Function(int length) _randomBytes;

  BackupCryptoCodec({
    Cipher? cipher,
    Pbkdf2? kdf,
    Uint8List Function(int length)? randomBytes,
  }) : _cipher = cipher ?? _defaultCipher,
       _kdf = kdf ?? _defaultKdf,
       _randomBytes = randomBytes ?? _secureRandomBytes;

  String? validatePassphrase(String passphrase, {String? confirmation}) {
    final normalizedPassphrase = _normalizePassphrase(passphrase);
    if (normalizedPassphrase == null) {
      return '\u5907\u4efd\u53e3\u4ee4\u81f3\u5c11\u9700\u8981 '
          '$minimumPassphraseLength '
          '\u4e2a\u5b57\u7b26\u3002';
    }

    if (confirmation != null && confirmation.trim() != normalizedPassphrase) {
      return _passphraseMismatchMessage;
    }

    return null;
  }

  Future<Uint8List> encrypt(
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

  Future<Uint8List> decrypt(
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
      throw Exception(_wrongPassphraseMessage);
    }
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  String? _normalizePassphrase(String passphrase) {
    final normalized = passphrase.trim();
    if (normalized.length < minimumPassphraseLength) {
      return null;
    }
    return normalized;
  }
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
          'format': BackupCryptoCodec.encryptedBackupFormat,
          'version': BackupCryptoCodec.encryptedBackupVersion,
          'algorithm': 'aes-256-gcm',
          'kdf': 'pbkdf2-hmac-sha256',
          'iterations': BackupCryptoCodec.pbkdf2Iterations,
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

      if (decoded['format'] != BackupCryptoCodec.encryptedBackupFormat ||
          decoded['version'] != BackupCryptoCodec.encryptedBackupVersion) {
        throw const FormatException();
      }

      return _EncryptedBackupEnvelope(
        salt: base64Decode(decoded['salt'] as String),
        nonce: base64Decode(decoded['nonce'] as String),
        mac: base64Decode(decoded['mac'] as String),
        cipherText: base64Decode(decoded['ciphertext'] as String),
      );
    } on FormatException {
      throw Exception(BackupCryptoCodec._invalidEncryptedBackupMessage);
    } on TypeError {
      throw Exception(BackupCryptoCodec._invalidEncryptedBackupMessage);
    }
  }
}
