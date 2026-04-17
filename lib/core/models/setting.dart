class Setting {
  static const Object _unset = Object();

  final String key;
  final String? value;
  final int updatedAt;

  const Setting({required this.key, this.value, required this.updatedAt});

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

  Setting copyWith({String? key, Object? value = _unset, int? updatedAt}) =>
      Setting(
        key: key ?? this.key,
        value: identical(value, _unset) ? this.value : value as String?,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Setting &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
}
