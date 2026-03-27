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
  static const _paperPanel = PdfColor.fromInt(0xF8FCFAF5);
  static const _paperPanelSoft = PdfColor.fromInt(0xEEF9F5ED);
  static const _inkPrimary = PdfColor.fromInt(0xFF2F3A2F);
  static const _inkSecondary = PdfColor.fromInt(0xFF8B7D6B);
  // 印章红
  static const _sealRed = PdfColor.fromInt(0xFFB44A3E);
  static const _sealRedSoft = PdfColor.fromInt(0x26B44A3E);
  static const _wusiLine = PdfColor.fromInt(0xFFD59A8B);
  static const _frameLine = PdfColor.fromInt(0xFFDCCFB9);
  static const _frameHairline = PdfColor.fromInt(0xFFF0E6D7);
  static const _washInk = PdfColor.fromInt(0x113F443A);
  static const _washInkDeep = PdfColor.fromInt(0x18393E35);
  static const _metricGreen = PdfColor.fromInt(0xFF6F8A68);
  static const _tableStripe = PdfColor.fromInt(0x0AF5F1E8);

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

    final body = pw.TextStyle(
      font: ttf,
      fontSize: 11.5,
      color: _inkPrimary,
    );
    final bodyStrong = pw.TextStyle(
      font: ttf,
      fontSize: 11.5,
      fontWeight: pw.FontWeight.bold,
      color: _inkPrimary,
    );
    final subtle = pw.TextStyle(
      font: ttf,
      fontSize: 9.5,
      color: _inkSecondary,
    );
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
    final totalFee =
        sortedRecords.fold<double>(0, (sum, record) => sum + record.feeAmount);
    final totalPaid =
        sortedPayments.fold<double>(0, (sum, payment) => sum + payment.amount);
    final balance = totalPaid - totalFee;
    final balanceLabel = balance >= 0 ? '结余' : '待收';
    final balanceValue = '¥${balance.abs().toStringAsFixed(2)}';
    final balanceAccent = balance >= 0 ? _metricGreen : _sealRed;
    final messageText = message.trim();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: ttf,
        bold: ttf,
      ),
    );

    pw.Widget buildWatermark() {
      return pw.Center(
        child: pw.Transform.rotate(
          angle: -0.52,
          child: pw.Opacity(
            opacity: 0.1,
            child: pw.Text(
              '$institutionName\n${student.name}研习册',
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

    // 印章组件 — 根据 SealConfig 动态渲染
    pw.Widget buildSealStamp({
      double size = 60,
      bool tilted = true,
    }) {
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
        child: tilted
            ? pw.Transform.rotate(angle: -0.08, child: stamp)
            : stamp,
      );
    }

    // 纸张背景装饰
    pw.Widget buildPaperBackground() {
      return pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.Container(color: _paperColor),
          ),
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
            child: pw.Container(
              width: 68,
              height: 1,
              color: _frameHairline,
            ),
          ),
          pw.Positioned(
            right: 28,
            bottom: 32,
            child: pw.Container(
              width: 82,
              height: 1,
              color: _frameHairline,
            ),
          ),
          if (watermarkWidget != null) watermarkWidget,
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
        buildBackground: (_) => pw.FullPage(
          ignoreMargins: true,
          child: buildPaperBackground(),
        ),
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
                          '$institutionName · 墨韵',
                          style: footerStyle,
                        ),
                        pw.Text(
                          '第 ${context.pageNumber} 页',
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
            pw.Text(
              value,
              style: bodyStrong.copyWith(fontSize: 10.8),
            ),
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
                      pw.Container(
                        width: 72,
                        height: 2.4,
                        color: _sealRed,
                      ),
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
                  pw.Text(
                    subtitle,
                    style: subtle.copyWith(fontSize: 10.3),
                  ),
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
              pw.Container(
                width: 28,
                height: 3,
                color: accent,
              ),
              pw.SizedBox(height: 10),
              pw.Text(label, style: subtle),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: bodyStrong.copyWith(
                  fontSize: 16,
                  color: accent,
                ),
              ),
              if (caption != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  caption,
                  style: subtle.copyWith(fontSize: 8.6),
                ),
              ],
            ],
          ),
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
            pw.Text(
              title,
              style: bodyStrong.copyWith(fontSize: 12.4),
            ),
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
          style: subtle.copyWith(
            fontSize: 8.8,
            color: accent,
          ),
        ),
      );
    }

    pw.Widget buildTableCell(
      String text, {
      pw.TextStyle? style,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      final content = text.trim().isEmpty ? '—' : text;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(
          content,
          style: style ?? body,
          textAlign: align,
        ),
      );
    }

    pw.Widget buildAttendanceLedger() {
      if (sortedRecords.isEmpty) {
        return buildPanel(
          title: '出勤册页',
          subtitle: '本周期暂无出勤记录。',
          child: pw.Text(
            '当前时间范围内没有可展示的课次，建议调整导出区间后重新生成。',
            style: body.copyWith(fontSize: 10.5),
          ),
        );
      }

      final rows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _sealRedSoft),
          children: [
            buildTableCell('日期', style: bodyStrong, align: pw.TextAlign.center),
            buildTableCell('时段', style: bodyStrong, align: pw.TextAlign.center),
            buildTableCell('状态', style: bodyStrong, align: pw.TextAlign.center),
            buildTableCell('费用', style: bodyStrong, align: pw.TextAlign.center),
          ],
        ),
        for (var i = 0; i < sortedRecords.length; i++)
          pw.TableRow(
            decoration: i.isEven ? const pw.BoxDecoration(color: _tableStripe) : null,
            children: [
              buildTableCell(sortedRecords[i].date),
              buildTableCell('${sortedRecords[i].startTime} – ${sortedRecords[i].endTime}'),
              buildTableCell(
                statusLabel(sortedRecords[i].status),
                align: pw.TextAlign.center,
              ),
              buildTableCell(
                '¥${sortedRecords[i].feeAmount.toStringAsFixed(0)}',
                align: pw.TextAlign.center,
              ),
            ],
          ),
      ];

      return buildPanel(
        title: '出勤册页',
        subtitle: '借细红界格规整课次、时段与费用，便于快速核对。',
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
                      buildTag('${record.startTime} – ${record.endTime}', accent: _sealRed),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    width: 40,
                    height: 2,
                    color: _sealRed,
                  ),
                  if (record.lessonFocusTags.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Text('课堂重点', style: bodyStrong.copyWith(fontSize: 10.6)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _formatLessonFocusTags(record),
                      style: body.copyWith(fontSize: 10.5, lineSpacing: 3),
                    ),
                  ],
                  if (record.homePracticeNote?.trim().isNotEmpty ?? false) ...[
                    pw.SizedBox(height: 10),
                    pw.Text('课后练习', style: bodyStrong.copyWith(fontSize: 10.6)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      record.homePracticeNote!.trim(),
                      style: body.copyWith(fontSize: 10.5, lineSpacing: 3),
                    ),
                  ],
                  pw.SizedBox(height: 10),
                  pw.Text('进步摘记', style: bodyStrong.copyWith(fontSize: 10.6)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _formatProgressSummary(record).isEmpty
                        ? '本次未填写评分，建议结合课堂重点一并查看。'
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
          title: '缴费流水',
          subtitle: '本周期暂无缴费记录。',
          child: pw.Text(
            '若本阶段未发生缴费，可仅参考上方应收与待收金额；如需补录，请先在应用内完善缴费记录。',
            style: body.copyWith(fontSize: 10.5, lineSpacing: 3),
          ),
        );
      }

      final rows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _sealRedSoft),
          children: [
            buildTableCell('缴费日期', style: bodyStrong, align: pw.TextAlign.center),
            buildTableCell('金额', style: bodyStrong, align: pw.TextAlign.center),
            buildTableCell('备注', style: bodyStrong, align: pw.TextAlign.center),
          ],
        ),
        for (var i = 0; i < sortedPayments.length; i++)
          pw.TableRow(
            decoration: i.isEven ? const pw.BoxDecoration(color: _tableStripe) : null,
            children: [
              buildTableCell(sortedPayments[i].paymentDate),
              buildTableCell(
                '¥${sortedPayments[i].amount.toStringAsFixed(2)}',
                align: pw.TextAlign.center,
              ),
              buildTableCell(sortedPayments[i].note ?? ''),
            ],
          ),
      ];

      return buildPanel(
        title: '缴费流水',
        subtitle: '保留日期与附注，方便家长逐笔核对。',
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

    // Page 1: 封面（压角章在此页，不放签名）
    pdf.addPage(
      pw.Page(
        pageTheme: buildTheme(
          showPageNumber: false,
          margin: const pw.EdgeInsets.fromLTRB(52, 56, 52, 56),
        ),
        build: (_) {
          final chips = <pw.Widget>[
            buildInfoChip('研习区间', '$from 至 $to'),
            buildInfoChip(
              '指导教师',
              teacherName.trim().isEmpty ? institutionName : teacherName.trim(),
            ),
            buildInfoChip('课次', '${sortedRecords.length} 节'),
          ];
          if (student.parentName?.trim().isNotEmpty ?? false) {
            chips.add(buildInfoChip('家长', student.parentName!.trim()));
          }

          return pw.Stack(
            children: [
              pw.Positioned(
                left: 0,
                top: 6,
                child: buildVerticalLabel('研习册'),
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
                        '学习报告',
                        style: bodyStrong.copyWith(
                          fontSize: 15.2,
                          letterSpacing: 2,
                          color: _inkSecondary,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        width: 96,
                        height: 2.4,
                        color: _sealRed,
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        '以纸墨留存本阶段的课录、札记与结算，让日常学习也有卷册般的归档感。',
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

    // Page 2: 出勤明细
    pdf.addPage(
      pw.MultiPage(
        pageTheme: buildTheme(),
        build: (_) => [
          buildSectionIntro(
            title: '出勤纪要',
            subtitle: '用古籍界格整理课次、时段与费用，让信息清楚而不生硬。',
            sideLabel: '课录',
          ),
          pw.Row(
            children: [
              buildMetricCard(
                label: '累计课次',
                value: '${sortedRecords.length} 节',
                accent: _inkPrimary,
                caption: '当前筛选区间内的课次总数',
              ),
              pw.SizedBox(width: 12),
              buildMetricCard(
                label: '累计时长',
                value: _formatDuration(totalMinutes),
                accent: _metricGreen,
                caption: '按课次起止时间折算',
              ),
              pw.SizedBox(width: 12),
              buildMetricCard(
                label: '课时单价',
                value: '¥${student.pricePerClass.toStringAsFixed(0)}',
                accent: _sealRed,
                caption: '默认课时价格快照',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          buildAttendanceLedger(),
        ],
      ),
    );

    if (feedbackRecords.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: buildTheme(),
          build: (_) => [
            buildSectionIntro(
              title: '课堂札记',
              subtitle: '把课堂重点、课后练习与评分收成册页式摘录，替代表格堆砌。',
              sideLabel: '札记',
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
            title: '费用结算',
            subtitle: '以薄墨梳理应收、已收与结余，方便家长核对本阶段课耗。',
            sideLabel: '款识',
          ),
          pw.Row(
            children: [
              buildMetricCard(
                label: '应收',
                value: '¥${totalFee.toStringAsFixed(2)}',
                accent: _inkPrimary,
                caption: '按出勤状态自动折算',
              ),
              pw.SizedBox(width: 12),
              buildMetricCard(
                label: '已收',
                value: '¥${totalPaid.toStringAsFixed(2)}',
                accent: _metricGreen,
                caption: '当前区间内的缴费合计',
              ),
              pw.SizedBox(width: 12),
              buildMetricCard(
                label: balanceLabel,
                value: balanceValue,
                accent: balanceAccent,
                caption: balance >= 0 ? '当前缴费已覆盖课耗' : '仍有课耗待结清',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          buildPaymentLedger(),
          pw.SizedBox(height: 16),
          buildPanel(
            title: '核对说明',
            subtitle: '若对金额有疑问，可结合出勤纪要页逐条复核。',
            child: pw.Text(
              '本报告中的费用以课次快照和出勤状态自动计算；缺勤、请假、试听等状态的计费逻辑，以应用当前规则为准。',
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

    if (messageText.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageTheme: buildTheme(),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildSectionIntro(
                title: '教师寄语',
                subtitle: '将评语留在卷尾，以手写式落款和朱砂印章收束全册。',
                sideLabel: '题跋',
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
                    pw.Text('寄语', style: calliSection),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      width: 56,
                      height: 2.2,
                      color: _sealRed,
                    ),
                    pw.SizedBox(height: 18),
                    pw.Text(
                      messageText,
                      style: body.copyWith(
                        fontSize: 13,
                        lineSpacing: 7,
                      ),
                    ),
                    pw.SizedBox(height: 24),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          if (signatureImage != null) ...[
                            pw.Image(signatureImage!, height: 48),
                            pw.SizedBox(height: 8),
                          ],
                          pw.Text(
                            teacherName.trim().isEmpty
                                ? '—— $institutionName'
                                : '—— ${teacherName.trim()}',
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
    final path = p.join(dir.path, '${student.name}_$from.pdf');
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
    if (minutes <= 0) return '0 分钟';
    if (minutes < 60) return '$minutes 分钟';

    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours 小时';
    return '$hours 小时 $rest 分钟';
  }
}
