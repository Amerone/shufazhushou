import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/seal_config.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/payment.dart';
import '../../shared/constants.dart';

class PdfGenerator {
  // 宣纸暖色
  static const _paperColor = PdfColor.fromInt(0xFFF5F1E8);
  // 印章红
  static const _sealRed = PdfColor.fromInt(0xFFB44A3E);

  static Future<String> generate({
    required Student student,
    required String from,
    required String to,
    required List<Attendance> records,
    required List<Payment> payments,
    required String teacherName,
    required String? signaturePath,
    required String message,
    required bool watermark,
    required SealConfig sealConfig,
    String institutionName = kDefaultInstitutionName,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final calliData = await rootBundle.load('assets/fonts/MaShanZheng-Regular.ttf');
    final calliFont = pw.Font.ttf(calliData);

    final style = pw.TextStyle(font: ttf);
    final bold = pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold);

    final pdf = pw.Document();

    // 水印 — 使用行书字体
    pw.Widget? watermarkWidget;
    if (watermark) {
      watermarkWidget = pw.Center(
        child: pw.Transform.rotate(
          angle: -0.5,
          child: pw.Opacity(
            opacity: 0.12,
            child: pw.Text(
              '$institutionName，仅供${student.name}家长核对',
              style: pw.TextStyle(font: calliFont, fontSize: 36),
            ),
          ),
        ),
      );
    }

    // 印章组件 — 根据 SealConfig 动态渲染
    pw.Widget sealStamp() {
      final grid = sealConfig.gridLayout;
      final isInverted = sealConfig.isInverted;
      final bgColor = isInverted ? _sealRed : null;
      final textColor = isInverted ? PdfColors.white : _sealRed;
      final charStyle = pw.TextStyle(font: calliFont, fontSize: 18, color: textColor);

      pw.BoxBorder? border;
      bool isUniformBorder = true;
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

      pw.Widget content;
      if (sealConfig.layout == 'diagonal') {
        content = pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text(grid[0][0], style: charStyle), pw.Text(grid[0][1], style: charStyle)],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text(grid[1][0], style: charStyle), pw.Text(grid[1][1], style: charStyle)],
              ),
            ],
          ),
        );
      } else {
        content = pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [pw.Text(grid[0][0], style: charStyle), pw.Text(grid[0][1], style: charStyle)],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [pw.Text(grid[1][0], style: charStyle), pw.Text(grid[1][1], style: charStyle)],
            ),
          ],
        );
      }

      return pw.Positioned(
        right: 24,
        bottom: 24,
        child: pw.Transform.rotate(
          angle: -0.08,
          child: pw.Opacity(
            opacity: 0.85,
            child: pw.Container(
              width: 56,
              height: 56,
              decoration: pw.BoxDecoration(
                color: bgColor,
                border: border,
                borderRadius: isUniformBorder ? pw.BorderRadius.circular(3) : null,
              ),
              padding: const pw.EdgeInsets.all(2),
              child: content,
            ),
          ),
        ),
      );
    }

    // 纸张背景装饰
    pw.Widget paperBackground() {
      return pw.Positioned.fill(
        child: pw.Container(
          decoration: const pw.BoxDecoration(color: _paperColor),
        ),
      );
    }

    pw.Widget? signatureWidget;
    if (signaturePath != null && signaturePath.isNotEmpty) {
      final sigFile = File(signaturePath);
      if (sigFile.existsSync()) {
        final sigBytes = await sigFile.readAsBytes();
        signatureWidget = pw.Image(pw.MemoryImage(sigBytes), height: 60);
      }
    }

    // Page 1: 封面（压角章在此页，不放签名）
    pdf.addPage(pw.Page(
      build: (ctx) => pw.Stack(children: [
        paperBackground(),
        ?watermarkWidget,
        pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(student.name, style: pw.TextStyle(font: calliFont, fontSize: 36)),
              pw.SizedBox(height: 12),
              pw.Text('学习报告', style: pw.TextStyle(font: calliFont, fontSize: 22, color: PdfColors.grey700)),
              pw.SizedBox(height: 16),
              pw.Text('$from ~ $to', style: style),
              pw.SizedBox(height: 32),
              if (teacherName.isNotEmpty)
                pw.Text(teacherName, style: style),
            ],
          ),
        ),
        sealStamp(),
      ]),
    ));

    // Page 2: 出勤明细
    pdf.addPage(pw.Page(
      build: (ctx) => pw.Stack(children: [
        paperBackground(),
        ?watermarkWidget,
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 24),
          child: pw.Column(children: [
            pw.Text('出勤明细', style: pw.TextStyle(font: calliFont, fontSize: 20)),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEDE8DC)),
                  children: [
                    _cell('日期', bold),
                    _cell('时间', bold),
                    _cell('状态', bold),
                    _cell('费用', bold),
                  ],
                ),
                ...records.map((r) => pw.TableRow(children: [
                  _cell(r.date, style),
                  _cell('${r.startTime}–${r.endTime}', style),
                  _cell(statusLabel(r.status), style),
                  _cell('¥${r.feeAmount.toStringAsFixed(0)}', style),
                ])),
              ],
            ),
          ]),
        ),
      ]),
    ));

    // Page 3: 费用结算
    final feedbackRecords = records
        .where((record) => _hasStructuredFeedback(record))
        .toList(growable: false);
    if (feedbackRecords.isNotEmpty) {
      pdf.addPage(pw.Page(
        build: (ctx) => pw.Stack(children: [
          paperBackground(),
          ?watermarkWidget,
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('课堂反馈摘要', style: pw.TextStyle(font: calliFont, fontSize: 20)),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEDE8DC)),
                      children: [
                        _cell('日期/时间', bold),
                        _cell('课堂重点', bold),
                        _cell('课后练习', bold),
                        _cell('进步评分', bold),
                      ],
                    ),
                    ...feedbackRecords.map(
                      (record) => pw.TableRow(
                        children: [
                          _cell('${record.date}\n${record.startTime}-${record.endTime}', style),
                          _cell(_formatLessonFocusTags(record), style),
                          _cell(record.homePracticeNote ?? '', style),
                          _cell(_formatProgressSummary(record), style),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ));
    }

    final totalFee = records.fold<double>(0, (s, r) => s + r.feeAmount);
    final totalPaid = payments.fold<double>(0, (s, pay) => s + pay.amount);
    final balance = totalPaid - totalFee;
    pdf.addPage(pw.Page(
      build: (ctx) => pw.Stack(children: [
        paperBackground(),
        ?watermarkWidget,
        pw.Center(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 40),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('费用结算', style: pw.TextStyle(font: calliFont, fontSize: 20)),
              pw.SizedBox(height: 12),
              pw.Text('应收：¥${totalFee.toStringAsFixed(2)}', style: style),
              pw.SizedBox(height: 4),
              pw.Text('已收：¥${totalPaid.toStringAsFixed(2)}', style: style),
              pw.Divider(color: PdfColors.grey400),
              pw.Text('余额：¥${balance.toStringAsFixed(2)}', style: bold),
            ]),
          ),
        ),
      ]),
    ));

    // Page 4: 寄语（若有）
    if (message.isNotEmpty) {
      pdf.addPage(pw.Page(
        build: (ctx) => pw.Stack(children: [
          paperBackground(),
          ?watermarkWidget,
          pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 40),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 60,
                    height: 1,
                    color: PdfColors.grey400,
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('寄语', style: pw.TextStyle(font: calliFont, fontSize: 28)),
                  pw.SizedBox(height: 20),
                  pw.Text(message, style: pw.TextStyle(font: ttf, fontSize: 14, lineSpacing: 8)),
                  pw.SizedBox(height: 24),
                  pw.Container(
                    width: 60,
                    height: 1,
                    color: PdfColors.grey400,
                  ),
                  if (teacherName.isNotEmpty) ...[
                    pw.SizedBox(height: 20),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('—— $teacherName', style: pw.TextStyle(font: calliFont, fontSize: 16, color: PdfColors.grey700)),
                    ),
                    if (signatureWidget != null) ...[
                      pw.SizedBox(height: 8),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: signatureWidget,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ]),
      ));
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, '${student.name}_$from.pdf');
    await File(path).writeAsBytes(await pdf.save());
    return path;
  }

  static pw.Widget _cell(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(text, style: style),
    );
  }

  static bool _hasStructuredFeedback(Attendance record) {
    return record.lessonFocusTags.isNotEmpty ||
        (record.homePracticeNote?.trim().isNotEmpty ?? false) ||
        !(record.progressScores?.isEmpty ?? true);
  }

  static String _formatLessonFocusTags(Attendance record) {
    if (record.lessonFocusTags.isEmpty) return '';
    return record.lessonFocusTags.join('、');
  }

  static String _formatProgressSummary(Attendance record) {
    final scores = record.progressScores;
    if (scores == null || scores.isEmpty) return '';

    final parts = <String>[];
    if (scores.strokeQuality != null) {
      parts.add('笔画 ${scores.strokeQuality!.toStringAsFixed(1)}');
    }
    if (scores.structureAccuracy != null) {
      parts.add('结构 ${scores.structureAccuracy!.toStringAsFixed(1)}');
    }
    if (scores.rhythmConsistency != null) {
      parts.add('节奏 ${scores.rhythmConsistency!.toStringAsFixed(1)}');
    }
    return parts.join(' / ');
  }
}
