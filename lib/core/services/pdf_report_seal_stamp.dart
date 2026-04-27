import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/seal_config.dart';

class PdfReportSealStamp {
  const PdfReportSealStamp._();

  static const PdfColor _sealRed = PdfColor.fromInt(0xFFB44A3E);

  static pw.Widget build({
    required SealConfig sealConfig,
    required pw.Font font,
    double size = 60,
    bool tilted = true,
  }) {
    final grid = sealConfig.gridLayout;
    final isInverted = sealConfig.isInverted;
    final bgColor = isInverted ? _sealRed : null;
    final textColor = isInverted ? PdfColors.white : _sealRed;
    final charStyle = pw.TextStyle(
      font: font,
      fontSize: size * 0.32,
      color: textColor,
    );

    pw.BoxBorder? border;
    var isUniformBorder = true;
    switch (sealConfig.border) {
      case 'full':
        border = pw.Border.all(color: _sealRed, width: 2);
        break;
      case 'broken':
        border = pw.Border(
          top: const pw.BorderSide(color: _sealRed, width: 2.4),
          right: const pw.BorderSide(color: _sealRed, width: 1.2),
          bottom: const pw.BorderSide(color: _sealRed, width: 1.6),
          left: const pw.BorderSide(color: _sealRed, width: 2.8),
        );
        isUniformBorder = false;
        break;
      case 'borrowed':
        border = const pw.Border(
          top: pw.BorderSide(color: _sealRed, width: 2),
          right: pw.BorderSide(color: _sealRed, width: 2),
          bottom: pw.BorderSide.none,
          left: pw.BorderSide.none,
        );
        isUniformBorder = false;
        break;
      case 'none':
        border = null;
        break;
      default:
        border = pw.Border.all(color: _sealRed, width: 2);
    }

    final content = sealConfig.layout == 'diagonal'
        ? pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(grid[0][0], style: charStyle),
                    pw.Text(grid[0][1], style: charStyle),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(grid[1][0], style: charStyle),
                    pw.Text(grid[1][1], style: charStyle),
                  ],
                ),
              ],
            ),
          )
        : pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  pw.Text(grid[0][0], style: charStyle),
                  pw.Text(grid[0][1], style: charStyle),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  pw.Text(grid[1][0], style: charStyle),
                  pw.Text(grid[1][1], style: charStyle),
                ],
              ),
            ],
          );

    final stamp = pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: border,
        borderRadius: isUniformBorder ? pw.BorderRadius.circular(4) : null,
      ),
      padding: const pw.EdgeInsets.all(3),
      child: content,
    );

    return pw.Opacity(
      opacity: 0.9,
      child: tilted ? pw.Transform.rotate(angle: -0.08, child: stamp) : stamp,
    );
  }
}
