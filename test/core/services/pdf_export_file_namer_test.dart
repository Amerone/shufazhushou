import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/pdf_export_file_namer.dart';

void main() {
  const namer = PdfExportFileNamer();

  group('PdfExportFileNamer', () {
    test('replaces invalid filename characters with underscores', () {
      expect(
        namer.sanitizeSegment('A/B:*?"<>|C', fallback: 'student'),
        'A_B_C',
      );
    });

    test('collapses whitespace and repeated underscores', () {
      expect(
        namer.sanitizeSegment('  foo   __   bar  ', fallback: 'student'),
        'foo_bar',
      );
    });

    test('falls back when the sanitized segment is empty', () {
      expect(
        namer.sanitizeSegment(
          '  . _ / \\ : * ? " < > |  ',
          fallback: 'student',
        ),
        'student',
      );
    });

    test('formats timestamps as yyyyMMddHHmmss', () {
      expect(
        namer.formatFileStamp(DateTime(2026, 4, 27, 9, 5, 7)),
        '20260427090507',
      );
    });

    test('builds the final PDF export file name', () {
      expect(
        namer.buildFileName(
          studentName: '  .Ada / Lovelace.  ',
          from: '2026/04/01',
          to: ' 2026:04:30 ',
          timestamp: DateTime(2026, 4, 27, 9, 5, 7),
        ),
        'Ada_Lovelace_2026_04_01_2026_04_30_20260427090507.pdf',
      );
    });
  });
}
