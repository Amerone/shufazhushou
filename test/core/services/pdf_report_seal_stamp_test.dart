import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/seal_config.dart';
import 'package:moyun/core/services/pdf_report_seal_stamp.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfReportSealStamp.build', () {
    test('renders supported seal variants into valid pdf bytes', () async {
      final font = await _loadTestFont();
      final cases = [
        _SealRenderCase(
          config: const SealConfig(
            text: 'ABCD',
            layout: 'grid',
            border: 'full',
          ),
        ),
        _SealRenderCase(
          config: const SealConfig(
            text: 'EFGH',
            layout: 'diagonal',
            border: 'broken',
          ),
          tilted: false,
        ),
        _SealRenderCase(
          config: const SealConfig(
            text: 'IJKL',
            layout: 'full_white',
            border: 'none',
          ),
          size: 72,
          tilted: false,
        ),
        _SealRenderCase(
          config: const SealConfig(
            text: 'MNOP',
            layout: 'fine_red',
            border: 'borrowed',
          ),
          size: 54,
        ),
      ];

      for (final testCase in cases) {
        final bytes = await _renderSeal(testCase, font);

        expect(bytes.length, greaterThan(1000));
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      }
    });
  });
}

Future<pw.Font> _loadTestFont() async {
  final fontData = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
  return pw.Font.ttf(fontData);
}

Future<Uint8List> _renderSeal(_SealRenderCase testCase, pw.Font font) async {
  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6,
      build: (_) => pw.Center(
        child: PdfReportSealStamp.build(
          sealConfig: testCase.config,
          font: font,
          size: testCase.size,
          tilted: testCase.tilted,
        ),
      ),
    ),
  );
  return document.save();
}

class _SealRenderCase {
  final SealConfig config;
  final double size;
  final bool tilted;

  const _SealRenderCase({
    required this.config,
    this.size = 60,
    this.tilted = true,
  });
}
