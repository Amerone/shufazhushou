class Payment {
  static const Object _unset = Object();

  final String id;
  final String studentId;
  final double amount;
  final String paymentDate; // YYYY-MM-DD
  final String? note;
  final int createdAt;

  const Payment({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.paymentDate,
    this.note,
    required this.createdAt,
  });

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
    id: m['id'] as String,
    studentId: m['student_id'] as String,
    amount: (m['amount'] as num).toDouble(),
    paymentDate: m['payment_date'] as String,
    note: m['note'] as String?,
    createdAt: m['created_at'] as int,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'student_id': studentId,
    'amount': amount,
    'payment_date': paymentDate,
    'note': note,
    'created_at': createdAt,
  };

  Payment copyWith({
    String? id,
    String? studentId,
    double? amount,
    String? paymentDate,
    Object? note = _unset,
    int? createdAt,
  }) => Payment(
    id: id ?? this.id,
    studentId: studentId ?? this.studentId,
    amount: amount ?? this.amount,
    paymentDate: paymentDate ?? this.paymentDate,
    note: identical(note, _unset) ? this.note : note as String?,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          studentId == other.studentId &&
          amount == other.amount &&
          paymentDate == other.paymentDate &&
          note == other.note &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id, studentId, amount, paymentDate, note, createdAt,
  );
}
