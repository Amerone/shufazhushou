import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/utils/excel_importer.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<int> buildWorkbook({
    required List<CellValue> header,
    required List<CellValue> row,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow(header);
    sheet.appendRow(row);
    return excel.encode()!;
  }

  test('parse supports the downloadable template headers', () {
    final bytes = buildWorkbook(
      header: [
        TextCellValue('\u5b66\u751f\u59d3\u540d'),
        TextCellValue('\u5bb6\u957f\u59d3\u540d'),
        TextCellValue('\u5bb6\u957f\u7535\u8bdd'),
        TextCellValue('\u8bfe\u65f6\u5355\u4ef7'),
      ],
      row: [
        TextCellValue('\u5f20\u4e09'),
        TextCellValue('\u674e\u5973\u58eb'),
        TextCellValue('13800000000'),
        TextCellValue('120'),
      ],
    );

    final preview = ExcelImporter.parse(bytes, const <Student>[]);

    expect(preview.errors, isEmpty);
    expect(preview.skipped, 0);
    expect(preview.toInsert, hasLength(1));
    expect(preview.toInsert.single.name, '\u5f20\u4e09');
    expect(preview.toInsert.single.parentName, '\u674e\u5973\u58eb');
    expect(preview.toInsert.single.parentPhone, '13800000000');
    expect(preview.toInsert.single.pricePerClass, 120);
  });
}
