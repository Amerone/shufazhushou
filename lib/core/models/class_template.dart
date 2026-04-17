class ClassTemplate {
  final String id;
  final String name;
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final int createdAt;

  const ClassTemplate({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
  });

  factory ClassTemplate.fromMap(Map<String, dynamic> m) => ClassTemplate(
    id: m['id'] as String,
    name: m['name'] as String,
    startTime: m['start_time'] as String,
    endTime: m['end_time'] as String,
    createdAt: m['created_at'] as int,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'start_time': startTime,
    'end_time': endTime,
    'created_at': createdAt,
  };

  ClassTemplate copyWith({
    String? id,
    String? name,
    String? startTime,
    String? endTime,
    int? createdAt,
  }) => ClassTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, name, startTime, endTime, createdAt);
}
