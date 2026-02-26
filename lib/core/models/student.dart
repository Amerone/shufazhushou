class Student {
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
    String? parentName,
    String? parentPhone,
    double? pricePerClass,
    String? status,
    String? note,
    int? createdAt,
    int? updatedAt,
  }) =>
      Student(
        id: id ?? this.id,
        name: name ?? this.name,
        parentName: parentName ?? this.parentName,
        parentPhone: parentPhone ?? this.parentPhone,
        pricePerClass: pricePerClass ?? this.pricePerClass,
        status: status ?? this.status,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// 构建 id → 显示名称 映射，仅重名学生附加后缀消歧
Map<String, String> buildDisplayNameMap(List<Student> students) {
  // 统计每个名字出现的次数
  final nameCount = <String, int>{};
  for (final s in students) {
    nameCount[s.name] = (nameCount[s.name] ?? 0) + 1;
  }
  final map = <String, String>{};
  for (final s in students) {
    if (nameCount[s.name]! > 1) {
      final suffix = s.parentName != null && s.parentName!.isNotEmpty
          ? s.parentName!
          : s.parentPhone != null && s.parentPhone!.length >= 4
              ? '...${s.parentPhone!.substring(s.parentPhone!.length - 4)}'
              : s.id.substring(0, 4);
      map[s.id] = '${s.name}（$suffix）';
    } else {
      map[s.id] = s.name;
    }
  }
  return map;
}
