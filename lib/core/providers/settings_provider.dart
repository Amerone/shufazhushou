import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/dao/settings_dao.dart';
import 'database_provider.dart';

final settingsDaoProvider = Provider((ref) =>
    SettingsDao(ref.watch(databaseProvider)));

class SettingsNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() {
    return ref.watch(settingsDaoProvider).getAll();
  }

  Future<void> set(String key, String value) async {
    // Optimistic update: immediately reflect the change in UI
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData({...current, key: value});
    }
    await ref.read(settingsDaoProvider).set(key, value);
  }

  Future<void> setAll(Map<String, String> entries) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData({...current, ...entries});
    }
    final dao = ref.read(settingsDaoProvider);
    for (final e in entries.entries) {
      await dao.set(e.key, e.value);
    }
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Map<String, String>>(
        SettingsNotifier.new);
