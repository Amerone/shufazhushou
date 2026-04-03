import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/export_template.dart';
import '../models/seal_config.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/payment.dart';
import '../services/student_growth_summary_service.dart';
import 'fee_calculator.dart';
import '../../shared/constants.dart';

class PdfGenerator {
  // The palette mirrors soft-textured stationery with a warm ivory glow.
  static const _paperColor = PdfColor.fromInt(0xFFF5F1E8);
  static const _paperPanel = PdfColor.fromInt(0xF8FCFAF5);
  static const _paperPanelSoft = PdfColor.fromInt(0xEEF9F5ED);
  static const _inkPrimary = PdfColor.fromInt(0xFF2F3A2F);
  static const _inkSecondary = PdfColor.fromInt(0xFF8B7D6B);
  // Deep seal red keeps calligraphic accents crisp against the soft background.
  static const _sealRed = PdfColor.fromInt(0xFFB44A3E);
  static const _sealRedSoft = PdfColor.fromInt(0x26B44A3E);
  static const _wusiLine = PdfColor.fromInt(0xFFD59A8B);
  static const _frameLine = PdfColor.fromInt(0xFFDCCFB9);
  static const _frameHairline = PdfColor.fromInt(0xFFF0E6D7);
  static const _washInk = PdfColor.fromInt(0x113F443A);
  static const _washInkDeep = PdfColor.fromInt(0x18393E35);
  static const _metricGreen = PdfColor.fromInt(0xFF6F8A68);
  static const _tableStripe = PdfColor.fromInt(0x0AF5F1E8);
  static final _invalidFileNameChars = RegExp(r'[\\/:*?"<>|]');
  static final _fileNameWhitespace = RegExp(r'\s+');
  static final _fileNameUnderscores = RegExp(r'_+');

  static Future<String> generate({
    required Student student,
    required String from,
    required String to,
    required List<Attendance> records,
    required List<Payment> payments,
    StudentFeeSummary? feeSummary,
    required String teacherName,
    required String? signaturePath,
    required String message,
    required bool watermark,
    required SealConfig sealConfig,
    required ExportTemplateId template,
    String? aiAnalysis,
    String institutionName = kDefaultInstitutionName,
  }) async {
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansSC-Regular.ttf',
    );
    final ttf = pw.Font.ttf(fontData);
    final calliData = await rootBundle.load(
      'assets/fonts/MaShanZheng-Regular.ttf',
    );
    final calliFont = pw.Font.ttf(calliData);

    final body = pw.TextStyle(font: ttf, fontSize: 11.5, color: _inkPrimary);
    final bodyStrong = pw.TextStyle(
      font: ttf,
      fontSize: 11.5,
      fontWeight: pw.FontWeight.bold,
      color: _inkPrimary,
    );
    final subtle = pw.TextStyle(font: ttf, fontSize: 9.5, color: _inkSecondary);
    final calliHero = pw.TextStyle(
      font: calliFont,
      fontSize: 34,
      color: _inkPrimary,
    );
    final calliSection = pw.TextStyle(
      font: calliFont,
      fontSize: 24,
      color: _inkPrimary,
    );
    final calliSignature = pw.TextStyle(
      font: calliFont,
      fontSize: 18,
      color: _inkSecondary,
    );

    final sortedRecords = [...records]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });
    final sortedPayments = [...payments]
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    final feedbackRecords = sortedRecords
        .where((record) => _hasStructuredFeedback(record))
        .toList(growable: false);
    final totalMinutes = sortedRecords.fold<int>(
      0,
      (sum, record) => sum + _durationMinutes(record.startTime, record.endTime),
    );
    final totalFee = sortedRecords.fold<double>(
      0,
      (sum, record) => sum + record.feeAmount,
    );
    final totalPaid = sortedPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final ledger = StudentLedgerView(
      balance: feeSummary?.balance ?? (totalPaid - totalFee),
      pricePerClass: student.pricePerClass,
      hasBalanceHistory: totalFee > 0 || totalPaid > 0,
    );
    final balance = ledger.balance;
    final balanceLabel = ledger.balanceStatusLabel;
    final balanceValue = 'CNY ${balance.abs().toStringAsFixed(2)}';
    final balanceAccent = switch (ledger.balanceState) {
      LedgerBalanceState.debt => _sealRed,
      LedgerBalanceState.settled => _inkSecondary,
      LedgerBalanceState.surplus => _metricGreen,
    };
    final messageText = message.trim();
    final aiAnalysisText = aiAnalysis?.trim() ?? '';
    final aiAnalysisParagraphs = _splitAiAnalysisParagraphs(aiAnalysisText);
    final growthSummary = const StudentGrowthSummaryService().build(
      records: sortedRecords,
      now: DateTime.now(),
    );

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
    );

    pw.Widget buildWatermark() {
      return pw.Center(
        child: pw.Transform.rotate(
          angle: -0.52,
          child: pw.Opacity(
            opacity: 0.1,
            child: pw.Text(
              '$institutionName\n${student.name}\n\u5b66\u4e60\u62a5\u544a',

              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: calliFont,
                fontSize: 31,
                color: _inkSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final watermarkWidget = watermark ? buildWatermark() : null;

    pw.Widget buildSealStamp({double size = 60, bool tilted = true}) {
      final grid = sealConfig.gridLayout;
      final isInverted = sealConfig.isInverted;
      final bgColor = isInverted ? _sealRed : null;
      final textColor = isInverted ? PdfColors.white : _sealRed;
      final charStyle = pw.TextStyle(
        font: calliFont,
        fontSize: size * 0.32,
        color: textColor,
      );

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
        );
      } else {
        content = pw.Column(
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
      }

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

    // The background layers mimic a calm ledger with rotated gradients and muted strokes.
    pw.Widget buildPaperBackground() {
      return pw.Stack(
        children: [
          pw.Positioned.fill(child: pw.Container(color: _paperColor)),
          pw.Positioned(
            top: -34,
            right: -10,
            child: pw.Transform.rotate(
              angle: 0.34,
              child: pw.Container(
                width: 190,
                height: 72,
                decoration: const pw.BoxDecoration(
                  color: _washInkDeep,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(36)),
                ),
              ),
            ),
          ),
          pw.Positioned(
            left: -34,
            bottom: 86,
            child: pw.Transform.rotate(
              angle: -0.48,
              child: pw.Container(
                width: 210,
                height: 58,
                decoration: const pw.BoxDecoration(
                  color: _washInk,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(32)),
                ),
              ),
            ),
          ),
          pw.Positioned(
            left: 30,
            top: 44,
            child: pw.Container(width: 68, height: 1, color: _frameHairline),
          ),
          pw.Positioned(
            right: 28,
            bottom: 32,
            child: pw.Container(width: 82, height: 1, color: _frameHairline),
          ),
          ?watermarkWidget,
        ],
      );
    }

    pw.PageTheme buildTheme({
      bool showPageNumber = true,
      pw.EdgeInsetsGeometry? margin,
    }) {
      final footerStyle = subtle.copyWith(fontSize: 8.8);
      return pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
        margin: margin ?? const pw.EdgeInsets.fromLTRB(48, 52, 48, 56),
        buildBackground: (_) =>
            pw.FullPage(ignoreMargins: true, child: buildPaperBackground()),
        buildForeground: showPageNumber
            ? (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(38, 0, 38, 18),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '$institutionName - \u58a8\u97f5',
                        style: footerStyle,
                      ),
                      pw.Text(
                        '\u7b2c ${context.pageNumber} \u9875',
                        style: footerStyle,
                      ),
                    ],
                  ),
                ),
              )
            : null,
      );
    }

    pw.Widget buildVerticalLabel(String label) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: pw.BoxDecoration(
          color: _paperPanel,
          border: pw.Border.all(color: _frameLine, width: 0.7),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            for (final char in label.split(''))
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: pw.Text(
                  char,
                  style: subtle.copyWith(letterSpacing: 1.2),
                ),
              ),
          ],
        ),
      );
    }

    pw.Widget buildInfoChip(String label, String value) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: _paperPanelSoft,
          border: pw.Border.all(color: _frameLine, width: 0.7),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: subtle),
            pw.SizedBox(height: 4),
            pw.Text(value, style: bodyStrong.copyWith(fontSize: 10.8)),
          ],
        ),
      );
    }

    pw.MemoryImage? signatureImage;
    if (signaturePath != null && signaturePath.isNotEmpty) {
      final sigFile = File(signaturePath);
      if (sigFile.existsSync()) {
        signatureImage = pw.MemoryImage(await sigFile.readAsBytes());
      }
    }

    pw.Widget buildSectionIntro({
      required String title,
      required String subtitle,
      required String sideLabel,
    }) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 18),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title, style: calliSection),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Container(width: 72, height: 2.4, color: _sealRed),
                      pw.SizedBox(width: 10),
                      pw.Container(
                        width: 18,
                        height: 18,
                        decoration: const pw.BoxDecoration(
                          color: _sealRedSoft,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(subtitle, style: subtle.copyWith(fontSize: 10.3)),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            buildVerticalLabel(sideLabel),
          ],
        ),
      );
    }

    pw.Widget buildMetricCard({
      required String label,
      required String value,
      required PdfColor accent,
      String? caption,
    }) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: pw.BoxDecoration(
            color: _paperPanel,
            border: pw.Border.all(color: _frameLine, width: 0.7),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(width: 28, height: 3, color: accent),
              pw.SizedBox(height: 10),
              pw.Text(label, style: subtle),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: bodyStrong.copyWith(fontSize: 16, color: accent),
              ),
              if (caption != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(caption, style: subtle.copyWith(fontSize: 8.6)),
              ],
            ],
          ),
        ),
      );
    }

    pw.Widget buildSnapshotCard({
      required String label,
      required String value,
      required PdfColor accent,
      int maxLines = 3,
    }) {
      return pw.Container(
        width: 180,
        padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: pw.BoxDecoration(
          color: _paperPanel,
          border: pw.Border.all(color: _frameLine, width: 0.7),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 26, height: 3, color: accent),
            pw.SizedBox(height: 10),
            pw.Text(label, style: subtle),
            pw.SizedBox(height: 6),
            pw.Text(
              value.trim().isEmpty ? '-' : value,
              style: bodyStrong.copyWith(fontSize: 10.8, color: accent),
              maxLines: maxLines,
            ),
          ],
        ),
      );
    }

    pw.Widget buildPanel({
      required String title,
      String? subtitle,
      required pw.Widget child,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: pw.BoxDecoration(
          color: _paperPanel,
          border: pw.Border.all(color: _frameLine, width: 0.8),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: bodyStrong.copyWith(fontSize: 12.4)),
            if (subtitle != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(subtitle, style: subtle),
            ],
            pw.SizedBox(height: 12),
            child,
          ],
        ),
      );
    }

    pw.Widget buildTag(String text, {PdfColor accent = _inkSecondary}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: _paperPanelSoft,
          border: pw.Border.all(color: _frameLine, width: 0.7),
          borderRadius: pw.BorderRadius.circular(999),
        ),
        child: pw.Text(
          text,
          style: subtle.copyWith(fontSize: 8.8, color: accent),
        ),
      );
    }

    pw.Widget buildTableCell(
      String text, {
      pw.TextStyle? style,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      final content = text.trim().isEmpty ? '-' : text;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(content, style: style ?? body, textAlign: align),
      );
    }

    pw.Widget buildAttendanceLedger() {
      if (sortedRecords.isEmpty) {
        return buildPanel(
          title: '\u51fa\u52e4\u8bb0\u5f55',
          subtitle:
              '\u5f53\u524d\u65f6\u95f4\u8303\u56f4\u5185\u6682\u65e0\u51fa\u52e4\u8bb0\u5f55\u3002',
          child: pw.Text(
            '\u672a\u5728\u6240\u9009\u65e5\u671f\u8303\u56f4\u5185\u627e\u5230\u8bfe\u7a0b\u8bb0\u5f55\uff0c\u53ef\u5c1d\u8bd5\u8c03\u6574\u5bfc\u51fa\u8303\u56f4\u3002',
            style: body.copyWith(fontSize: 10.5),
          ),
        );
      }

      final rows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _sealRedSoft),
          children: [
            buildTableCell(
              '\u65e5\u671f',
              style: bodyStrong,
              align: pw.TextAlign.center,
            ),
            buildTableCell(
              '\u65f6\u95f4',
              style: bodyStrong,
              align: pw.TextAlign.center,
            ),
            buildTableCell(
              '\u72b6\u6001',
              style: bodyStrong,
              align: pw.TextAlign.center,
            ),
            buildTableCell(
              '\u8d39\u7528',
              style: bodyStrong,
              align: pw.TextAlign.center,
            ),
          ],
        ),
        for (var i = 0; i < sortedRecords.length; i++)
          pw.TableRow(
            decoration: i.isEven
                ? const pw.BoxDecoration(color: _tableStripe)
                : null,
            children: [
              buildTableCell(sortedRecords[i].date),
              buildTableCell(
                '${sortedRecords[i].startTime} - ${sortedRecords[i].endTime}',
              ),
              buildTableCell(
                _formatStatusLabel(sortedRecords[i].status),
                align: pw.TextAlign.center,
              ),
              buildTableCell(
                'CNY ${sortedRecords[i].feeAmount.toStringAsFixed(2)}',
                align: pw.TextAlign.center,
              ),
            ],
          ),
      ];

      return buildPanel(
        title: '\u51fa\u52e4\u8bb0\u5f55',
        subtitle:
            '\u6309\u8bfe\u7a0b\u65f6\u95f4\u4e0e\u8d39\u7528\u6c47\u603b\uff0c\u4fbf\u4e8e\u5feb\u901f\u67e5\u770b\u3002',
        child: pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1.35),
            1: pw.FlexColumnWidth(1.5),
            2: pw.FlexColumnWidth(0.9),
            3: pw.FlexColumnWidth(0.85),
          },
          border: const pw.TableBorder(
            top: pw.BorderSide(color: _wusiLine, width: 0.7),
            right: pw.BorderSide(color: _frameLine, width: 0.7),
            bottom: pw.BorderSide(color: _frameLine, width: 0.7),
            left: pw.BorderSide(color: _wusiLine, width: 0.7),
            horizontalInside: pw.BorderSide(color: _frameHairline, width: 0.5),
            verticalInside: pw.BorderSide(color: _frameHairline, width: 0.5),
          ),
          children: rows,
        ),
      );
    }

    pw.Widget buildFeedbackGallery() {
      return pw.Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final record in feedbackRecords)
            pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: pw.BoxDecoration(
                color: _paperPanel,
                border: pw.Border.all(color: _frameLine, width: 0.8),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      buildTag(record.date),
                      buildTag(
                        '${record.startTime} - ${record.endTime}',
                        accent: _sealRed,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(width: 40, height: 2, color: _sealRed),
                  if (record.lessonFocusTags.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Text(
                      '\u8bfe\u5802\u91cd\u70b9',
                      style: bodyStrong.copyWith(fontSize: 10.6),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _formatLessonFocusTags(record),
                      style: body.copyWith(fontSize: 10.5, lineSpacing: 3),
                    ),
                  ],
                  if (record.homePracticeNote?.trim().isNotEmpty ?? false) ...[
                    pw.SizedBox(height: 10),
                    pw.Text(
                      '\u8fdb\u6b65\u6458\u8981',
                      style: bodyStrong.copyWith(fontSize: 10.6),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      record.homePracticeNote!.trim(),
                      style: body.copyWith(fontSize: 10.5, lineSpacing: 3),
                    ),
                  ],
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '\u8fdb\u6b65\u8bb0\u5f55',
                    style: bodyStrong.copyWith(fontSize: 10.6),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _formatProgressSummary(record).isEmpty
                        ? '\u672c\u6b21\u8bfe\u5802\u6682\u65e0\u7ed3\u6784\u5316\u8bc4\u5206\uff0c\u8bf7\u7ed3\u5408\u5907\u6ce8\u4e0e\u91cd\u70b9\u6807\u7b7e\u67e5\u770b\u3002'
                        : _formatProgressSummary(record),
                    style: body.copyWith(
                      fontSize: 10.5,
                      color: _inkSecondary,
                      lineSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    pw.Widget buildPaymentLedger() {
      if (sortedPayments.isEmpty) {
        return buildPanel(
          title: '\u7f34\u8d39\u8bb0\u5f55',
          subtitle:
              '\u5f53\u524d\u65f6\u95f4\u8303\u56f4\u5185\u6682\u65e0\u7f34\u8d39\u8bb0\u5f55\u3002',
          child: pw.Text(
            '\u672c\u65f6\u95f4\u8303\u56f4\u5185\u672a\u8bb0\u5f55\u7f34\u8d39\uff0c\u4ecd\u53ef\u67e5\u770b\u5e94\u6536\u4e0e\u672a\u7ed3\u91d1\u989d\u3002',
            style: body.copyWith(fontSize: 10.5, lineSpacing: 3),
          ),
        );
      }

      final rows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _sealRedSoft),
          children: [
            buildTableCell(
              '\u7f34\u8d39\u65e5\u671f',
              style: bodyStrong,
              align: pw.TextAlign.center,
            ),
            buildTableCell(
              '\u91d1\u989d',
              style: bodyStrong,
              align: pw.TextAlign.center,
            ),
            buildTableCell(
              '\u5907\u6ce8',
              style: bodyStrong,
              align: pw.TextAlign.center,
            ),
          ],
        ),
        for (var i = 0; i < sortedPayments.length; i++)
          pw.TableRow(
            decoration: i.isEven
                ? const pw.BoxDecoration(color: _tableStripe)
                : null,
            children: [
              buildTableCell(sortedPayments[i].paymentDate),
              buildTableCell(
                'CNY ${sortedPayments[i].amount.toStringAsFixed(2)}',
                align: pw.TextAlign.center,
              ),
              buildTableCell(sortedPayments[i].note ?? ''),
            ],
          ),
      ];

      return buildPanel(
        title: '\u7f34\u8d39\u8bb0\u5f55',
        subtitle:
            '\u4fdd\u7559\u65e5\u671f\u4e0e\u5907\u6ce8\uff0c\u4fbf\u4e8e\u5bb6\u957f\u4fa7\u6838\u5bf9\u3002',
        child: pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1.15),
            1: pw.FlexColumnWidth(0.9),
            2: pw.FlexColumnWidth(2.2),
          },
          border: const pw.TableBorder(
            top: pw.BorderSide(color: _wusiLine, width: 0.7),
            right: pw.BorderSide(color: _frameLine, width: 0.7),
            bottom: pw.BorderSide(color: _frameLine, width: 0.7),
            left: pw.BorderSide(color: _wusiLine, width: 0.7),
            horizontalInside: pw.BorderSide(color: _frameHairline, width: 0.5),
            verticalInside: pw.BorderSide(color: _frameHairline, width: 0.5),
          ),
          children: rows,
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageTheme: buildTheme(
          showPageNumber: false,
          margin: const pw.EdgeInsets.fromLTRB(52, 56, 52, 56),
        ),
        build: (_) {
          final chips = <pw.Widget>[
            buildInfoChip('\u5468\u671f', '$from \u81f3 $to'),
            buildInfoChip('\u6a21\u677f', template.label),
            buildInfoChip(
              '\u6388\u8bfe\u6559\u5e08',
              teacherName.trim().isEmpty ? institutionName : teacherName.trim(),
            ),
          ];
          if (student.parentName?.trim().isNotEmpty ?? false) {
            chips.add(
              buildInfoChip('\u5bb6\u957f', student.parentName!.trim()),
            );
          }

          final coverTitle = switch (template) {
            ExportTemplateId.parentMonthly => '\u6210\u957f\u6708\u62a5',
            ExportTemplateId.teacherDetailed => '\u5b66\u4e60\u8be6\u62a5',
            ExportTemplateId.financeStatement =>
              '\u8d39\u7528\u5bf9\u8d26\u5355',
          };
          final coverSubtitle = switch (template) {
            ExportTemplateId.parentMonthly =>
              '\u9996\u9875\u805a\u7126\u5bb6\u957f\u6700\u5173\u5fc3\u7684\u4f59\u989d\u3001\u8fdb\u6b65\u70b9\u4e0e\u8bfe\u540e\u5efa\u8bae\u3002',
            ExportTemplateId.teacherDetailed =>
              '\u6c47\u603b\u8bfe\u6b21\u3001\u8bfe\u5802\u8bb0\u5f55\u4e0e\u7ed3\u7b97\u4fe1\u606f\uff0c\u65b9\u4fbf\u6559\u5b66\u7559\u6863\u3002',
            ExportTemplateId.financeStatement =>
              '\u9996\u9875\u805a\u7126\u5e94\u6536\u3001\u5df2\u6536\u4e0e\u4f59\u989d\uff0c\u4fbf\u4e8e\u6708\u672b\u6838\u5bf9\u3002',
          };

          final coverSnapshots = switch (template) {
            ExportTemplateId.parentMonthly => <pw.Widget>[
              buildSnapshotCard(
                label: balanceLabel,
                value: balanceValue,
                accent: balanceAccent,
              ),
              buildSnapshotCard(
                label: '\u4e0b\u6b21\u8bfe',
                value: growthSummary.nextLessonLabel,
                accent: _sealRed,
              ),
              buildSnapshotCard(
                label: '\u8fdb\u6b65\u70b9',
                value: growthSummary.progressPoint,
                accent: _metricGreen,
              ),
              buildSnapshotCard(
                label: '\u5f85\u5de9\u56fa\u70b9',
                value: growthSummary.attentionPoint,
                accent: _sealRed,
              ),
              buildSnapshotCard(
                label: '\u8bfe\u540e\u5efa\u8bae',
                value: growthSummary.practiceSummary,
                accent: _inkPrimary,
              ),
            ],
            ExportTemplateId.teacherDetailed => <pw.Widget>[
              buildSnapshotCard(
                label: '\u8bfe\u6b21',
                value: '${sortedRecords.length} \u8282',
                accent: _inkPrimary,
              ),
              buildSnapshotCard(
                label: '\u6700\u8fd1\u8bfe\u5802',
                value: growthSummary.latestLessonLabel,
                accent: _sealRed,
              ),
              buildSnapshotCard(
                label: '\u8bfe\u5802\u91cd\u70b9',
                value: growthSummary.focusTags.isEmpty
                    ? '\u6682\u65e0'
                    : growthSummary.focusTags.join('\u3001'),
                accent: _metricGreen,
              ),
            ],
            ExportTemplateId.financeStatement => <pw.Widget>[
              buildSnapshotCard(
                label: '\u5e94\u6536',
                value: 'CNY ${totalFee.toStringAsFixed(2)}',
                accent: _inkPrimary,
              ),
              buildSnapshotCard(
                label: '\u5df2\u6536',
                value: 'CNY ${totalPaid.toStringAsFixed(2)}',
                accent: _metricGreen,
              ),
              buildSnapshotCard(
                label: balanceLabel,
                value: balanceValue,
                accent: balanceAccent,
              ),
              buildSnapshotCard(
                label: '\u6700\u8fd1\u8bfe\u5802',
                value: growthSummary.latestLessonLabel,
                accent: _sealRed,
              ),
            ],
          };

          return pw.Stack(
            children: [
              pw.Positioned(
                left: 0,
                top: 6,
                child: buildVerticalLabel('\u62a5\u544a'),
              ),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Container(
                  width: 430,
                  padding: const pw.EdgeInsets.fromLTRB(28, 34, 28, 30),
                  decoration: pw.BoxDecoration(
                    color: _paperPanel,
                    border: pw.Border.all(color: _frameLine, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        institutionName,
                        style: subtle.copyWith(letterSpacing: 2),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 18),
                      pw.Text(student.name, style: calliHero),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        coverTitle,
                        style: bodyStrong.copyWith(
                          fontSize: 15.2,
                          letterSpacing: 2,
                          color: _inkSecondary,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Container(width: 96, height: 2.4, color: _sealRed),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        coverSubtitle,
                        style: body.copyWith(
                          fontSize: 11,
                          color: _inkSecondary,
                          lineSpacing: 3,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 20),
                      pw.Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: pw.WrapAlignment.center,
                        children: chips,
                      ),
                      pw.SizedBox(height: 18),
                      pw.Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: pw.WrapAlignment.center,
                        children: coverSnapshots,
                      ),
                      if (template == ExportTemplateId.parentMonthly) ...[
                        pw.SizedBox(height: 14),
                        pw.Text(
                          '\u6570\u636e\u622a\u6b62\u81f3 ${growthSummary.dataFreshness}',
                          style: subtle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: buildSealStamp(size: 68),
              ),
            ],
          );
        },
      ),
    );

    // Page 2: The attendance summary keeps classes, timing, and fees organized in a compact ledger layout.
    pdf.addPage(
      pw.MultiPage(
        pageTheme: buildTheme(),
        build: (_) => [
          buildSectionIntro(
            title: '\u51fa\u52e4\u6982\u89c8',
            subtitle:
                '\u4ee5\u7b80\u6d01\u8d26\u518c\u65b9\u5f0f\u6574\u7406\u8bfe\u7a0b\u65e5\u671f\u3001\u65f6\u6bb5\u4e0e\u8d39\u7528\u3002',
            sideLabel: '\u8bfe\u7a0b',
          ),
          pw.Row(
            children: [
              buildMetricCard(
                label: '\u8bfe\u6b21',
                value: '${sortedRecords.length} \u8282',
                accent: _inkPrimary,
                caption:
                    '\u6240\u9009\u65f6\u95f4\u8303\u56f4\u5185\u7684\u603b\u8bfe\u6b21',
              ),
              pw.SizedBox(width: 12),
              buildMetricCard(
                label: '\u603b\u65f6\u957f',
                value: _formatDuration(totalMinutes),
                accent: _metricGreen,
                caption:
                    '\u6839\u636e\u4e0a\u8bfe\u5f00\u59cb\u4e0e\u7ed3\u675f\u65f6\u95f4\u8ba1\u7b97',
              ),
              pw.SizedBox(width: 12),
              buildMetricCard(
                label: '\u8bfe\u65f6\u5355\u4ef7',
                value: 'CNY ${student.pricePerClass.toStringAsFixed(0)}',
                accent: _sealRed,
                caption: '\u5f53\u524d\u8bfe\u65f6\u4ef7\u683c\u5feb\u7167',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          buildAttendanceLedger(),
        ],
      ),
    );

    if (feedbackRecords.isNotEmpty &&
        template != ExportTemplateId.financeStatement) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: buildTheme(),
          build: (_) => [
            buildSectionIntro(
              title: '\u8bfe\u5802\u8bb0\u5f55',
              subtitle:
                  '\u4ee5\u5361\u7247\u65b9\u5f0f\u5c55\u793a\u91cd\u70b9\u6807\u7b7e\u3001\u8bfe\u540e\u7ec3\u4e60\u4e0e\u8bc4\u5206\u6458\u8981\u3002',
              sideLabel: '\u8bb0\u5f55',
            ),
            buildFeedbackGallery(),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: buildTheme(),
        build: (_) => [
          buildSectionIntro(
            title: '\u8d39\u7528\u6c47\u603b',
            subtitle:
                '\u6c47\u603b\u672c\u5468\u671f\u7684\u5e94\u6536\u3001\u5df2\u6536\u4e0e\u4f59\u989d\u60c5\u51b5\u3002',
            sideLabel: '\u8d39\u7528',
          ),
          pw.Row(
            children: [
              buildMetricCard(
                label: '\u5e94\u6536',
                value: 'CNY ${totalFee.toStringAsFixed(2)}',
                accent: _inkPrimary,
                caption:
                    '\u6839\u636e\u51fa\u52e4\u72b6\u6001\u81ea\u52a8\u8ba1\u7b97',
              ),
              pw.SizedBox(width: 12),
              buildMetricCard(
                label: '\u5df2\u6536',
                value: 'CNY ${totalPaid.toStringAsFixed(2)}',
                accent: _metricGreen,
                caption:
                    '\u672c\u5468\u671f\u5185\u8bb0\u5f55\u7684\u603b\u7f34\u8d39',
              ),
              pw.SizedBox(width: 12),
              buildMetricCard(
                label: balanceLabel,
                value: balanceValue,
                accent: balanceAccent,
                caption: balance >= 0
                    ? '\u5f53\u524d\u7f34\u8d39\u5df2\u8986\u76d6\u5b66\u8d39'
                    : '\u4ecd\u6709\u5f85\u7ed3\u5b66\u8d39',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          buildPaymentLedger(),
          pw.SizedBox(height: 16),
          buildPanel(
            title: '\u5bf9\u8d26\u8bf4\u660e',
            subtitle:
                '\u5982\u679c\u91d1\u989d\u5b58\u5728\u51fa\u5165\uff0c\u8bf7\u7ed3\u5408\u51fa\u52e4\u8bb0\u5f55\u6838\u5bf9\u3002',
            child: pw.Text(
              '\u62a5\u544a\u4e2d\u7684\u8d39\u7528\u6839\u636e\u51fa\u52e4\u5feb\u7167\u4e0e\u72b6\u6001\u8ba1\u8d39\u89c4\u5219\u81ea\u52a8\u751f\u6210\u3002',
              style: body.copyWith(fontSize: 10.5, lineSpacing: 3),
            ),
          ),
          if (messageText.isEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: buildSealStamp(size: 54),
            ),
          ],
        ],
      ),
    );

    if (aiAnalysisText.isNotEmpty &&
        template != ExportTemplateId.financeStatement) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: buildTheme(),
          build: (_) => [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildSectionIntro(
                  title: 'AI \u5b66\u4e60\u5206\u6790',
                  subtitle:
                      '\u6c47\u603b\u8fd1\u671f\u8bfe\u5802\u8868\u73b0\u4e0e\u6559\u5b66\u5efa\u8bae\uff0c\u4fbf\u4e8e\u5bb6\u6821\u540c\u6b65\u8bfe\u5802\u8fdb\u5c55\u3002',
                  sideLabel: 'AI',
                ),
                pw.SizedBox(height: 8),
                pw.Text('\u5206\u6790\u5185\u5bb9', style: calliSection),
                pw.SizedBox(height: 10),
                pw.Container(width: 56, height: 2.2, color: _sealRed),
                pw.SizedBox(height: 16),
              ],
            ),
            ...(aiAnalysisParagraphs.isEmpty
                    ? [aiAnalysisText]
                    : aiAnalysisParagraphs)
                .map(
                  (paragraph) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Text(
                      paragraph,
                      style: body.copyWith(fontSize: 12.2, lineSpacing: 5),
                    ),
                  ),
                ),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: buildSealStamp(size: 56),
            ),
          ],
        ),
      );
    }

    if (messageText.isNotEmpty &&
        template != ExportTemplateId.financeStatement) {
      pdf.addPage(
        pw.Page(
          pageTheme: buildTheme(),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildSectionIntro(
                title: '\u6559\u5e08\u5bc4\u8bed',
                subtitle:
                    '\u4ee5\u6559\u5e08\u5bc4\u8bed\u3001\u7b7e\u540d\u4e0e\u5370\u7ae0\u4e3a\u62a5\u544a\u6536\u5c3e\u3002',
                sideLabel: '\u5bc4\u8bed',
              ),
              pw.SizedBox(height: 18),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.fromLTRB(26, 28, 26, 30),
                decoration: pw.BoxDecoration(
                  color: _paperPanel,
                  border: pw.Border.all(color: _frameLine, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('\u5bc4\u8bed', style: calliSection),
                    pw.SizedBox(height: 10),
                    pw.Container(width: 56, height: 2.2, color: _sealRed),
                    pw.SizedBox(height: 18),
                    pw.Text(
                      messageText,
                      style: body.copyWith(fontSize: 13, lineSpacing: 7),
                    ),
                    pw.SizedBox(height: 24),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          if (signatureImage != null) ...[
                            pw.Image(signatureImage, height: 48),
                            pw.SizedBox(height: 8),
                          ],
                          pw.Text(
                            teacherName.trim().isEmpty
                                ? '\u7531 $institutionName \u51fa\u5177'
                                : '\u7531 ${teacherName.trim()} \u51fa\u5177',
                            style: calliSignature,
                          ),
                          pw.SizedBox(height: 10),
                          buildSealStamp(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final safeStudentName = _sanitizeFileNameSegment(
      student.name,
      fallback: 'student',
    );
    final safeFrom = _sanitizeFileNameSegment(from, fallback: 'from');
    final safeTo = _sanitizeFileNameSegment(to, fallback: 'to');
    final fileStamp = _formatFileStamp(DateTime.now());
    final path = p.join(
      dir.path,
      '${safeStudentName}_${safeFrom}_${safeTo}_$fileStamp.pdf',
    );
    await File(path).writeAsBytes(await pdf.save());
    return path;
  }

  static bool _hasStructuredFeedback(Attendance record) {
    return record.lessonFocusTags.isNotEmpty ||
        (record.homePracticeNote?.trim().isNotEmpty ?? false) ||
        !(record.progressScores?.isEmpty ?? true);
  }

  static String _formatLessonFocusTags(Attendance record) {
    if (record.lessonFocusTags.isEmpty) return '';
    return record.lessonFocusTags.join(', ');
  }

  static String _formatProgressSummary(Attendance record) {
    final scores = record.progressScores;
    if (scores == null || scores.isEmpty) return '';

    final parts = <String>[];
    if (scores.strokeQuality != null) {
      parts.add(
        '\u7b14\u753b\u8d28\u91cf\uff1a${scores.strokeQuality!.toStringAsFixed(1)}',
      );
    }
    if (scores.structureAccuracy != null) {
      parts.add(
        '\u7ed3\u6784\u51c6\u786e\u5ea6\uff1a${scores.structureAccuracy!.toStringAsFixed(1)}',
      );
    }
    if (scores.rhythmConsistency != null) {
      parts.add(
        '\u8282\u594f\u7a33\u5b9a\u6027\uff1a${scores.rhythmConsistency!.toStringAsFixed(1)}',
      );
    }
    return parts.join(' / ');
  }

  static String _formatStatusLabel(String status) {
    switch (status) {
      case 'present':
        return '\u51fa\u52e4';
      case 'late':
        return '\u8fdf\u5230';
      case 'leave':
        return '\u8bf7\u5047';
      case 'absent':
        return '\u7f3a\u52e4';
      case 'trial':
        return '\u8bd5\u542c';
      default:
        return status;
    }
  }

  static List<String> _splitAiAnalysisParagraphs(String text) {
    if (text.isEmpty) return const [];

    final byBlankLine = text
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
    if (byBlankLine.length > 1) return byBlankLine;

    final byLine = text
        .split(RegExp(r'\n+'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
    if (byLine.length > 1) return byLine;

    final bySentence =
        RegExp(r'[^\u3002\uFF01\uFF1F!?]+[\u3002\uFF01\uFF1F!?]?')
            .allMatches(text)
            .map((match) => match.group(0)?.trim() ?? '')
            .where((paragraph) => paragraph.isNotEmpty)
            .toList(growable: false);
    if (bySentence.length > 1) return bySentence;

    return [text];
  }

  static int _durationMinutes(String startTime, String endTime) {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    if (startParts.length != 2 || endParts.length != 2) return 0;

    final startHour = int.tryParse(startParts[0]) ?? 0;
    final startMinute = int.tryParse(startParts[1]) ?? 0;
    final endHour = int.tryParse(endParts[0]) ?? 0;
    final endMinute = int.tryParse(endParts[1]) ?? 0;

    final startTotal = startHour * 60 + startMinute;
    final endTotal = endHour * 60 + endMinute;
    final diff = endTotal - startTotal;
    return diff > 0 ? diff : 0;
  }

  static String _formatDuration(int minutes) {
    if (minutes <= 0) return '0\u5206\u949f';
    if (minutes < 60) return '$minutes\u5206\u949f';

    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours\u5c0f\u65f6';
    return '$hours\u5c0f\u65f6 $rest\u5206\u949f';
  }

  static String _sanitizeFileNameSegment(
    String value, {
    required String fallback,
  }) {
    final sanitized = value
        .trim()
        .replaceAll(_invalidFileNameChars, '_')
        .replaceAll(_fileNameWhitespace, '_')
        .replaceAll(_fileNameUnderscores, '_')
        .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    return sanitized.isEmpty ? fallback : sanitized;
  }

  static String _formatFileStamp(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '${time.year}$month$day$hour$minute$second';
  }
}
