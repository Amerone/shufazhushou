import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dao/settings_dao.dart';
import '../models/qwen_vision_config.dart';
import '../services/sensitive_settings_store.dart';
import 'database_provider.dart';

final settingsDaoProvider = Provider(
  (ref) => SettingsDao(ref.watch(databaseProvider)),
);

final sensitiveSettingsStoreProvider = Provider(
  (ref) => SensitiveSettingsStore(),
);

const _sensitiveSettingKeys = <String>{QwenVisionConfig.settingApiKey};

class SettingsNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    final dao = ref.watch(settingsDaoProvider);
    final sensitiveStore = ref.watch(sensitiveSettingsStoreProvider);
    Map<String, String> settings = const {};
    Map<String, String> sensitive = const {};

    try {
      settings = await dao.getAll();
    } catch (error) {
      debugPrint('Failed to load settings from database: $error');
      settings = const {};
    }

    try {
      sensitive = {...await sensitiveStore.readAll()};
    } catch (error) {
      debugPrint('Failed to load sensitive settings: $error');
      // Security store may fail on some platforms; keep database settings.
      return {...settings};
    }

    final merged = {...settings};

    for (final key in _sensitiveSettingKeys) {
      final dbValue = settings[key]?.trim();
      final localValue = sensitive[key]?.trim();

      if (localValue != null && localValue.isNotEmpty) {
        merged[key] = sensitive[key]!;
      } else if (dbValue != null && dbValue.isNotEmpty) {
        try {
          await sensitiveStore.set(key, dbValue);
          merged[key] = dbValue;
        } catch (error) {
          debugPrint('Failed to migrate sensitive setting "$key": $error');
          merged[key] = dbValue;
          continue;
        }
      } else {
        continue;
      }

      try {
        await dao.delete(key);
      } catch (error) {
        debugPrint(
          'Failed to remove migrated sensitive setting "$key": $error',
        );
      }
    }

    return merged;
  }

  Future<void> set(String key, String value) async {
    final current = state.valueOrNull;
    if (_sensitiveSettingKeys.contains(key)) {
      try {
        await _persistSensitiveSetting(key, value);
      } catch (error, stackTrace) {
        if (current != null) {
          state = AsyncData(current);
        }
        debugPrint('Failed to persist sensitive setting "$key": $error');
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (current != null) {
        state = AsyncData({...current, key: value});
      }
      return;
    }
    // Optimistic update: immediately reflect the change in UI for non-sensitive settings.
    if (current != null) {
      state = AsyncData({...current, key: value});
    }
    await ref.read(settingsDaoProvider).set(key, value);
  }

  Future<void> setAll(Map<String, String> entries) async {
    final current = state.valueOrNull;
    final dao = ref.read(settingsDaoProvider);
    try {
      for (final e in entries.entries) {
        if (_sensitiveSettingKeys.contains(e.key)) {
          await _persistSensitiveSetting(e.key, e.value);
        }
      }
      for (final e in entries.entries) {
        if (_sensitiveSettingKeys.contains(e.key)) {
          continue;
        }
        await dao.set(e.key, e.value);
      }
    } catch (error, stackTrace) {
      if (current != null) {
        state = AsyncData(current);
      }
      debugPrint('Failed to persist settings: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (current != null) {
      state = AsyncData({...current, ...entries});
    }
  }

  Future<void> _persistSensitiveSetting(String key, String value) async {
    final dao = ref.read(settingsDaoProvider);
    await ref.read(sensitiveSettingsStoreProvider).set(key, value);
    try {
      await dao.delete(key);
    } catch (error) {
      debugPrint('Failed to remove legacy sensitive setting "$key": $error');
      rethrow;
    }
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Map<String, String>>(
      SettingsNotifier.new,
    );
