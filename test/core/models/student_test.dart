import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/student.dart';

void main() {
  test('copyWith allows clearing nullable student fields', () {
    const student = Student(
      id: 'student-1',
      name: 'Alice',
      parentName: 'Parent A',
      parentPhone: '13900000001',
      pricePerClass: 180,
      status: 'active',
      note: 'Needs weekend classes',
      createdAt: 1,
      updatedAt: 1,
    );

    final cleared = student.copyWith(
      parentName: null,
      parentPhone: null,
      note: null,
    );

    expect(cleared.parentName, isNull);
    expect(cleared.parentPhone, isNull);
    expect(cleared.note, isNull);
  });
}
