import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SensitiveSettingsStore {
  static const _fileName = 'sensitive_settings.json';

  Future<Map<String, String>> readAll() async {
    final file = await _file();
    if (!await file.exists()) return const <String, String>{};

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const <String, String>{};

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, String>{};

      final result = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! String) continue;
        final normalized = value.trim();
        if (normalized.isEmpty) continue;
        result[key] = normalized;
      }
      return result;
    } on FileSystemException {
      return const <String, String>{};
    } on FormatException {
      return const <String, String>{};
    }
  }

  Future<void> set(String key, String value) async {
    final all = await readAll();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      all.remove(key);
    } else {
      all[key] = normalized;
    }
    await _writeAll(all);
  }

  Future<void> clearAll() async {
    await _writeAll(const <String, String>{});
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<void> _writeAll(Map<String, String> values) async {
    final file = await _file();
    if (values.isEmpty) {
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(values),
      flush: true,
    );
  }
}
