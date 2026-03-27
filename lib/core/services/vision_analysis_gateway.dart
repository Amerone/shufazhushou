class VisionAnalysisRequest {
  final String prompt;
  final String imageSource;
  final double temperature;

  const VisionAnalysisRequest({
    required this.prompt,
    required this.imageSource,
    this.temperature = 0.2,
  });
}

class VisionAnalysisResult {
  final String model;
  final String text;
  final Map<String, dynamic> raw;

  const VisionAnalysisResult({
    required this.model,
    required this.text,
    required this.raw,
  });
}

class VisionAnalysisException implements Exception {
  final String message;

  const VisionAnalysisException(this.message);

  @override
  String toString() => 'VisionAnalysisException: $message';
}

abstract class VisionAnalysisGateway {
  Future<VisionAnalysisResult> analyze(VisionAnalysisRequest request);
}
