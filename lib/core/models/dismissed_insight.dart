class DismissedInsight {
  static const Object _unset = Object();

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
    Object? studentId = _unset,
    int? dismissedAt,
  }) => DismissedInsight(
    id: id ?? this.id,
    insightType: insightType ?? this.insightType,
    studentId: identical(studentId, _unset)
        ? this.studentId
        : studentId as String?,
    dismissedAt: dismissedAt ?? this.dismissedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DismissedInsight &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          insightType == other.insightType &&
          studentId == other.studentId &&
          dismissedAt == other.dismissedAt;

  @override
  int get hashCode => Object.hash(id, insightType, studentId, dismissedAt);
}
