class Student {
  static const Object _unset = Object();

  final String id;
  final String name;
  final String? parentName;
  final String? parentPhone;
  final double pricePerClass;
  final String status;
  final String? note;
  final int createdAt;
  final int updatedAt;

  const Student({
    required this.id,
    required this.name,
    this.parentName,
    this.parentPhone,
    required this.pricePerClass,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Student.fromMap(Map<String, dynamic> m) => Student(
    id: m['id'] as String,
    name: m['name'] as String,
    parentName: m['parent_name'] as String?,
    parentPhone: m['parent_phone'] as String?,
    pricePerClass: (m['price_per_class'] as num).toDouble(),
    status: m['status'] as String,
    note: m['note'] as String?,
    createdAt: m['created_at'] as int,
    updatedAt: m['updated_at'] as int,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'parent_name': parentName,
    'parent_phone': parentPhone,
    'price_per_class': pricePerClass,
    'status': status,
    'note': note,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  Student copyWith({
    String? id,
    String? name,
    Object? parentName = _unset,
    Object? parentPhone = _unset,
    double? pricePerClass,
    String? status,
    Object? note = _unset,
    int? createdAt,
    int? updatedAt,
  }) => Student(
    id: id ?? this.id,
    name: name ?? this.name,
    parentName: identical(parentName, _unset)
        ? this.parentName
        : parentName as String?,
    parentPhone: identical(parentPhone, _unset)
        ? this.parentPhone
        : parentPhone as String?,
    pricePerClass: pricePerClass ?? this.pricePerClass,
    status: status ?? this.status,
    note: identical(note, _unset) ? this.note : note as String?,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          parentName == other.parentName &&
          parentPhone == other.parentPhone &&
          pricePerClass == other.pricePerClass &&
          status == other.status &&
          note == other.note &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id, name, parentName, parentPhone,
    pricePerClass, status, note, createdAt, updatedAt,
  );
}

/// 构建 id 到显示名称的映射，仅为重名学员追加后缀消歧。
Map<String, String> buildDisplayNameMap(List<Student> students) {
  final nameCount = <String, int>{};
  for (final student in students) {
    nameCount[student.name] = (nameCount[student.name] ?? 0) + 1;
  }

  final map = <String, String>{};
  for (final student in students) {
    if (nameCount[student.name]! > 1) {
      final suffix =
          student.parentName != null && student.parentName!.isNotEmpty
          ? student.parentName!
          : student.parentPhone != null && student.parentPhone!.length >= 4
          ? '...${student.parentPhone!.substring(student.parentPhone!.length - 4)}'
          : student.id.substring(0, 4);
      map[student.id] = '${student.name}（$suffix）';
    } else {
      map[student.id] = student.name;
    }
  }
  return map;
}
