import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';

class InteractionFeedback {
  static const hapticsEnabledKey = 'interaction_haptics_enabled';
  static const soundEnabledKey = 'interaction_sound_enabled';

  static DateTime? _lastSelectionAt;

  static Map<String, String>? _settingsFor(BuildContext context) {
    return ProviderScope.containerOf(context, listen: false)
        .read(settingsProvider)
        .valueOrNull;
  }

  static bool isHapticsEnabled(BuildContext context) {
    return _settingsFor(context)?[hapticsEnabledKey] != 'false';
  }

  static bool isSoundEnabled(BuildContext context) {
    return _settingsFor(context)?[soundEnabledKey] == 'true';
  }

  static Future<void> selection(BuildContext context) async {
    if (!isHapticsEnabled(context)) return;

    final now = DateTime.now();
    if (_lastSelectionAt != null &&
        now.difference(_lastSelectionAt!) <
            const Duration(milliseconds: 48)) {
      return;
    }
    _lastSelectionAt = now;
    await HapticFeedback.selectionClick();
  }

  static Future<void> pageTurn(BuildContext context) async {
    await selection(context);
    if (!isSoundEnabled(context)) return;
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> seal(BuildContext context) async {
    if (isHapticsEnabled(context)) {
      await HapticFeedback.mediumImpact();
    }
    if (!isSoundEnabled(context)) return;
    await SystemSound.play(SystemSoundType.click);
  }
}
