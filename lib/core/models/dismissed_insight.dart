class DismissedInsight {
  final String id;
  final String insightType; // debt | renewal | churn | peak | trial | progress
  final String? studentId;
  final int dismissedAt;

  const DismissedInsight({
    required this.id,
    required this.insightType,
    this.studentId,
    required this.dismissedAt,
  });

  factory DismissedInsight.fromMap(Map<String, dynamic> m) => DismissedInsight(
        id: m['id'] as String,
        insightType: m['insight_type'] as String,
        studentId: m['student_id'] as String?,
        dismissedAt: m['dismissed_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'insight_type': insightType,
        'student_id': studentId,
        'dismissed_at': dismissedAt,
      };

  DismissedInsight copyWith({
    String? id,
    String? insightType,
    String? studentId,
    int? dismissedAt,
  }) =>
      DismissedInsight(
        id: id ?? this.id,
        insightType: insightType ?? this.insightType,
        studentId: studentId ?? this.studentId,
        dismissedAt: dismissedAt ?? this.dismissedAt,
      );
}
