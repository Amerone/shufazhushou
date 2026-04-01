import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/utils/excel_exporter.dart';

void main() {
  group('ExcelExporter', () {
    test('sanitizes student export file names', () {
      final fileName = ExcelExporter.buildStudentExportFileName(
        studentName: 'A/B:*?"<>|  C',
        from: '2026/04/01',
        to: ' 2026:04:30 ',
      );

      expect(fileName, 'A_B_C_2026_04_01_2026_04_30.xlsx');
    });

    test('sanitizes attendance export file names', () {
      final fileName = ExcelExporter.buildAttendanceExportFileName(
        from: '../2026/04/01',
        to: r'2026\04\30',
      );

      expect(fileName, 'attendance_2026_04_01_2026_04_30.xlsx');
    });
  });
}
