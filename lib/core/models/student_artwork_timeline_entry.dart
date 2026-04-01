class StudentArtworkTimelineEntry {
  final DateTime createdAt;
  final String lessonDate;
  final String lessonTimeRange;
  final String summary;
  final String strokeObservation;
  final String structureObservation;
  final String layoutObservation;
  final List<String> practiceSuggestions;
  final List<String> focusTags;
  final String progressLabel;
  final String scoreSummary;

  const StudentArtworkTimelineEntry({
    required this.createdAt,
    required this.lessonDate,
    required this.lessonTimeRange,
    required this.summary,
    required this.strokeObservation,
    required this.structureObservation,
    required this.layoutObservation,
    required this.practiceSuggestions,
    required this.focusTags,
    required this.progressLabel,
    required this.scoreSummary,
  });

  String get lessonLabel =>
      lessonTimeRange.isEmpty ? lessonDate : '$lessonDate $lessonTimeRange';

  String get primaryObservation {
    for (final value in [
      summary,
      structureObservation,
      strokeObservation,
      layoutObservation,
    ]) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }
}
