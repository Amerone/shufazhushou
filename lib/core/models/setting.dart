class Setting {
  final String key;
  final String? value;
  final int updatedAt;

  const Setting({
    required this.key,
    this.value,
    required this.updatedAt,
  });

  factory Setting.fromMap(Map<String, dynamic> m) => Setting(
        key: m['key'] as String,
        value: m['value'] as String?,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'key': key,
        'value': value,
        'updated_at': updatedAt,
      };

  Setting copyWith({String? key, String? value, int? updatedAt}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
