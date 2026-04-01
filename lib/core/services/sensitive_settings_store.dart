import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SensitiveSettingsStore {
  static const _fileName = 'sensitive_settings.json';
  static const _storage = FlutterSecureStorage();

  Future<Map<String, String>> readAll() async {
    await _migrateLegacyFileIfNeeded();
    final storedValues = await _storage.readAll();
    return _normalizeMap(storedValues);
  }

  Future<void> set(String key, String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await _storage.delete(key: key);
      return;
    }

    await _storage.write(key: key, value: normalized);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<void> _migrateLegacyFileIfNeeded() async {
    final legacyValues = await _readLegacyFile();
    if (legacyValues.isEmpty) {
      return;
    }

    final secureValues = _normalizeMap(await _storage.readAll());
    for (final entry in legacyValues.entries) {
      if (secureValues[entry.key]?.isNotEmpty == true) {
        continue;
      }
      await _storage.write(key: entry.key, value: entry.value);
    }

    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Map<String, String>> _readLegacyFile() async {
    final file = await _file();
    if (!await file.exists()) return const <String, String>{};

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const <String, String>{};

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, String>{};

      return _normalizeMap(decoded);
    } on FileSystemException {
      return const <String, String>{};
    } on FormatException {
      return const <String, String>{};
    }
  }

  Map<String, String> _normalizeMap(Map<dynamic, dynamic> raw) {
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! String) continue;
      final normalized = value.trim();
      if (normalized.isEmpty) continue;
      result[key] = normalized;
    }
    return result;
  }
}
