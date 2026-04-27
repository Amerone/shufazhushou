import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moyun/core/models/qwen_vision_config.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/services/sensitive_settings_store.dart';
import 'package:moyun/core/database/dao/settings_dao.dart';

void main() {
  group('SettingsNotifier build', () {
    test('keeps DB values when sensitive store read fails', () async {
      final dao = _FakeSettingsDao(
        initialValues: const {
          'normal_setting': 'value',
          QwenVisionConfig.settingApiKey: 'legacy-key',
        },
      );
      final sensitive = _FakeSensitiveSettingsStore(shouldThrowRead: true);

      final container = ProviderContainer(
        overrides: [
          settingsDaoProvider.overrideWithValue(dao),
          sensitiveSettingsStoreProvider.overrideWithValue(sensitive),
        ],
      );
      addTearDown(container.dispose);

      final settings = await container.read(settingsProvider.future);

      expect(settings['normal_setting'], 'value');
      expect(settings[QwenVisionConfig.settingApiKey], 'legacy-key');
    });

    test('migrates legacy sensitive settings into secure store', () async {
      final dao = _FakeSettingsDao(
        initialValues: const {QwenVisionConfig.settingApiKey: 'legacy-key'},
      );
      final sensitive = _FakeSensitiveSettingsStore(initialValues: const {});

      final container = ProviderContainer(
        overrides: [
          settingsDaoProvider.overrideWithValue(dao),
          sensitiveSettingsStoreProvider.overrideWithValue(sensitive),
        ],
      );
      addTearDown(container.dispose);

      final settings = await container.read(settingsProvider.future);

      expect(settings[QwenVisionConfig.settingApiKey], 'legacy-key');
      expect(
        sensitive.savedValues[QwenVisionConfig.settingApiKey],
        'legacy-key',
      );
      expect(dao.deletedKeys, contains(QwenVisionConfig.settingApiKey));
    });

    test('prefers secure sensitive setting over empty DB value', () async {
      final dao = _FakeSettingsDao(
        initialValues: const {QwenVisionConfig.settingApiKey: '   '},
      );
      final sensitive = _FakeSensitiveSettingsStore(
        initialValues: const {QwenVisionConfig.settingApiKey: 'secure-key'},
      );
      final container = ProviderContainer(
        overrides: [
          settingsDaoProvider.overrideWithValue(dao),
          sensitiveSettingsStoreProvider.overrideWithValue(sensitive),
        ],
      );
      addTearDown(container.dispose);

      final settings = await container.read(settingsProvider.future);

      expect(settings[QwenVisionConfig.settingApiKey], 'secure-key');
      expect(dao.deletedKeys, contains(QwenVisionConfig.settingApiKey));
    });

    test(
      'keeps DB sensitive value when migration to secure store fails',
      () async {
        final dao = _FakeSettingsDao(
          initialValues: const {QwenVisionConfig.settingApiKey: 'legacy-key'},
        );
        final sensitive = _FakeSensitiveSettingsStore(
          initialValues: const {},
          shouldThrowWrite: true,
        );

        final container = ProviderContainer(
          overrides: [
            settingsDaoProvider.overrideWithValue(dao),
            sensitiveSettingsStoreProvider.overrideWithValue(sensitive),
          ],
        );
        addTearDown(container.dispose);

        final settings = await container.read(settingsProvider.future);

        expect(settings[QwenVisionConfig.settingApiKey], 'legacy-key');
        expect(dao.deletedKeys, isEmpty);
        expect(sensitive.savedValues, isEmpty);
      },
    );
  });

  group('SettingsNotifier mutation', () {
    test(
      'keeps legacy sensitive value and rolls back state when secure write fails',
      () async {
        final dao = _FakeSettingsDao(
          initialValues: const {QwenVisionConfig.settingApiKey: 'legacy-key'},
        );
        final sensitive = _FakeSensitiveSettingsStore(
          initialValues: const {QwenVisionConfig.settingApiKey: 'legacy-key'},
          shouldThrowRead: true,
          shouldThrowWrite: true,
        );
        final container = ProviderContainer(
          overrides: [
            settingsDaoProvider.overrideWithValue(dao),
            sensitiveSettingsStoreProvider.overrideWithValue(sensitive),
          ],
        );
        addTearDown(container.dispose);
        await container.read(settingsProvider.future);

        await expectLater(
          () => container
              .read(settingsProvider.notifier)
              .set(QwenVisionConfig.settingApiKey, 'new-key'),
          throwsException,
        );

        expect(dao.deletedKeys, isEmpty);
        expect(
          sensitive.currentValues[QwenVisionConfig.settingApiKey],
          'legacy-key',
        );
        expect(
          container
              .read(settingsProvider)
              .valueOrNull?[QwenVisionConfig.settingApiKey],
          'legacy-key',
        );
      },
    );

    test(
      'setAll keeps legacy sensitive value and rolls back state when secure write fails',
      () async {
        final dao = _FakeSettingsDao(
          initialValues: const {QwenVisionConfig.settingApiKey: 'legacy-key'},
        );
        final sensitive = _FakeSensitiveSettingsStore(
          initialValues: const {QwenVisionConfig.settingApiKey: 'legacy-key'},
          shouldThrowRead: true,
          shouldThrowWrite: true,
        );
        final container = ProviderContainer(
          overrides: [
            settingsDaoProvider.overrideWithValue(dao),
            sensitiveSettingsStoreProvider.overrideWithValue(sensitive),
          ],
        );
        addTearDown(container.dispose);
        await container.read(settingsProvider.future);

        await expectLater(
          () => container.read(settingsProvider.notifier).setAll(const {
            QwenVisionConfig.settingApiKey: 'new-key',
            'teacher_name': 'Teacher',
          }),
          throwsException,
        );

        expect(dao.deletedKeys, isEmpty);
        expect(dao.upserts, isEmpty);
        expect(
          sensitive.currentValues[QwenVisionConfig.settingApiKey],
          'legacy-key',
        );
        expect(
          container
              .read(settingsProvider)
              .valueOrNull?[QwenVisionConfig.settingApiKey],
          'legacy-key',
        );
      },
    );

    test(
      'clears sensitive setting from legacy DB row when value is emptied',
      () async {
        final dao = _FakeSettingsDao(
          initialValues: const {QwenVisionConfig.settingApiKey: 'legacy-key'},
        );
        final sensitive = _FakeSensitiveSettingsStore(
          initialValues: const {QwenVisionConfig.settingApiKey: 'legacy-key'},
        );
        final container = ProviderContainer(
          overrides: [
            settingsDaoProvider.overrideWithValue(dao),
            sensitiveSettingsStoreProvider.overrideWithValue(sensitive),
          ],
        );
        addTearDown(container.dispose);
        await container.read(settingsProvider.future);

        await container
            .read(settingsProvider.notifier)
            .set(QwenVisionConfig.settingApiKey, '');

        expect(dao.deletedKeys, contains(QwenVisionConfig.settingApiKey));
        expect(
          sensitive.currentValues,
          isNot(contains(QwenVisionConfig.settingApiKey)),
        );
      },
    );
  });
}

class _FakeSettingsDao implements SettingsDao {
  _FakeSettingsDao({Map<String, String> initialValues = const {}}) {
    _values = Map<String, String>.from(initialValues);
  }

  final List<String> deletedKeys = [];
  final List<MapEntry<String, String>> upserts = [];
  late final Map<String, String> _values;

  @override
  Future<Map<String, String>> getAll() async =>
      Map<String, String>.from(_values);

  @override
  Future<String?> get(String key) async => _values[key];

  @override
  Future<void> set(String key, String value) async {
    upserts.add(MapEntry(key, value));
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deletedKeys.add(key);
    _values.remove(key);
  }
}

class _FakeSensitiveSettingsStore extends SensitiveSettingsStore {
  _FakeSensitiveSettingsStore({
    Map<String, String> initialValues = const {},
    this.shouldThrowRead = false,
    this.shouldThrowWrite = false,
  }) {
    _values = Map<String, String>.from(initialValues);
  }

  final bool shouldThrowRead;
  final bool shouldThrowWrite;
  late final Map<String, String> _values;
  final List<String> savedKeys = [];
  final List<MapEntry<String, String>> savedValuesList = [];

  Map<String, String> get savedValues => Map<String, String>.from(_values);
  Map<String, String> get currentValues => _values;

  @override
  Future<Map<String, String>> readAll() async {
    if (shouldThrowRead) {
      throw Exception('read failed');
    }
    return Map<String, String>.from(_values);
  }

  @override
  Future<void> set(String key, String value) async {
    savedKeys.add(key);
    if (shouldThrowWrite) {
      throw Exception('write failed');
    }
    final trimmed = value.trim();
    savedValuesList.add(MapEntry(key, trimmed));
    if (trimmed.isEmpty) {
      _values.remove(key);
      return;
    }
    _values[key] = trimmed;
  }
}
