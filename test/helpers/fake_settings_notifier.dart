import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  static const Map<String, String> _defaultSettings = {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };

  static Map<String, String> seededSettings = _defaultSettings;

  static void reset() {
    seededSettings = _defaultSettings;
  }

  @override
  Future<Map<String, String>> build() async => seededSettings;

  @override
  Future<void> set(String key, String value) async {
    seededSettings = {...seededSettings, key: value};
    state = AsyncData(seededSettings);
  }

  @override
  Future<void> setAll(Map<String, String> entries) async {
    seededSettings = {...seededSettings, ...entries};
    state = AsyncData(seededSettings);
  }
}
