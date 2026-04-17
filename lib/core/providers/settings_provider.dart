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
    final settings = await dao.getAll();
    final sensitive = {...await sensitiveStore.readAll()};

    for (final key in _sensitiveSettingKeys) {
      final dbValue = settings[key]?.trim();
      final localValue = sensitive[key]?.trim();
      if (dbValue == null || dbValue.isEmpty) continue;

      if (localValue == null || localValue.isEmpty) {
        await sensitiveStore.set(key, dbValue);
        sensitive[key] = dbValue;
      }
      await dao.delete(key);
      settings.remove(key);
    }

    return {
      ...settings,
      for (final key in _sensitiveSettingKeys)
        if (sensitive[key]?.isNotEmpty == true) key: sensitive[key]!,
    };
  }

  Future<void> set(String key, String value) async {
    // Optimistic update: immediately reflect the change in UI
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData({...current, key: value});
    }
    if (_sensitiveSettingKeys.contains(key)) {
      await ref.read(sensitiveSettingsStoreProvider).set(key, value);
      return;
    }
    await ref.read(settingsDaoProvider).set(key, value);
  }

  Future<void> setAll(Map<String, String> entries) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData({...current, ...entries});
    }
    final dao = ref.read(settingsDaoProvider);
    final sensitiveStore = ref.read(sensitiveSettingsStoreProvider);
    for (final e in entries.entries) {
      if (_sensitiveSettingKeys.contains(e.key)) {
        await sensitiveStore.set(e.key, e.value);
        continue;
      }
      await dao.set(e.key, e.value);
    }
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Map<String, String>>(
      SettingsNotifier.new,
    );
