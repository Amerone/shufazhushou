import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/data_insight_service.dart';
import '../models/qwen_vision_config.dart';
import '../services/handwriting_analysis_service.dart';
import '../services/progress_analysis_service.dart';
import '../services/qwen_vision_gateway.dart';
import '../services/vision_analysis_gateway.dart';
import 'settings_provider.dart';

final qwenVisionConfigProvider = Provider<QwenVisionConfig>((ref) {
  final settings =
      ref.watch(settingsProvider).valueOrNull ?? const <String, String>{};
  return QwenVisionConfig.fromSettings(settings);
});

final aiIncludeStudentNameProvider = Provider<bool>((ref) {
  final settings =
      ref.watch(settingsProvider).valueOrNull ?? const <String, String>{};
  return settings[QwenVisionConfig.settingIncludeStudentName] == 'true';
});

final visionAnalysisGatewayProvider = Provider<VisionAnalysisGateway?>((ref) {
  final config = ref.watch(qwenVisionConfigProvider);
  if (!config.isConfigured) return null;
  final gateway = QwenVisionGateway(config: config);
  ref.onDispose(gateway.dispose);
  return gateway;
});

final handwritingAnalysisServiceProvider =
    Provider<HandwritingAnalysisService?>((ref) {
      final gateway = ref.watch(visionAnalysisGatewayProvider);
      if (gateway == null) return null;
      return HandwritingAnalysisService(
        gateway: gateway,
        includeStudentNameByDefault: ref.watch(aiIncludeStudentNameProvider),
      );
    });

final progressAnalysisServiceProvider = Provider<ProgressAnalysisService?>((
  ref,
) {
  final gateway = ref.watch(visionAnalysisGatewayProvider);
  if (gateway == null) return null;
  return ProgressAnalysisService(gateway: gateway);
});

final dataInsightServiceProvider = Provider<DataInsightService?>((ref) {
  final gateway = ref.watch(visionAnalysisGatewayProvider);
  if (gateway == null) return null;
  return DataInsightService(gateway: gateway);
});
