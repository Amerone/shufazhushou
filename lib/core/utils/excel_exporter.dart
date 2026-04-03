import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/constants.dart';
import '../models/attendance.dart';
import '../models/payment.dart';
import '../models/student.dart';
import 'fee_calculator.dart';

class ExcelExporter {
  static final _invalidFileNameChars = RegExp(r'[\\/:*?"<>|]');
  static final _fileNameWhitespace = RegExp(r'\s+');
  static final _fileNameUnderscores = RegExp(r'_+');

  static Future<String> export({
    required Student student,
    required String from,
    required String to,
    required List<Attendance> records,
    required List<Payment> payments,
    StudentFeeSummary? feeSummary,
  }) async {
    final excel = Excel.createExcel();

    final detail = excel['出勤明细'];
    detail.appendRow([
      TextCellValue('日期'),
      TextCellValue('开始时间'),
      TextCellValue('结束时间'),
      TextCellValue('状态'),
      TextCellValue('单价快照'),
      TextCellValue('费用'),
      TextCellValue('备注'),
    ]);
    detail.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0)).value =
        TextCellValue('课堂重点');
    detail.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0)).value =
        TextCellValue('课后练习');
    detail.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0)).value =
        TextCellValue('进步评分');
    for (final record in records) {
      final row = [
        TextCellValue(record.date),
        TextCellValue(record.startTime),
        TextCellValue(record.endTime),
        TextCellValue(statusLabel(record.status)),
        DoubleCellValue(record.priceSnapshot),
        DoubleCellValue(record.feeAmount),
        TextCellValue(record.note ?? ''),
      ];
      row.addAll([
        TextCellValue(_formatLessonFocusTags(record)),
        TextCellValue(record.homePracticeNote ?? ''),
        TextCellValue(_formatProgressSummary(record)),
      ]);
      detail.appendRow(row);

      final rowIdx = detail.maxRows - 1;
      final bgColor = record.status == 'absent'
          ? ExcelColor.fromHexString('#FFCCCC')
          : record.status == 'leave'
          ? ExcelColor.fromHexString('#EEEEEE')
          : null;
      if (bgColor == null) {
        continue;
      }
      for (var col = 0; col < row.length; col++) {
        final cell = detail.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx),
        );
        cell.cellStyle = CellStyle(backgroundColorHex: bgColor);
      }
    }

    final summary = excel['费用汇总'];
    final totalFee =
        feeSummary?.totalReceivable ??
        records.fold<double>(0, (sum, item) => sum + item.feeAmount);
    final totalPaid =
        feeSummary?.totalReceived ??
        payments.fold<double>(0, (sum, item) => sum + item.amount);
    final openingBalance = feeSummary?.openingBalance ?? 0;
    final periodNetChange =
        feeSummary?.periodNetChange ?? (totalPaid - totalFee);
    final endingBalance = feeSummary?.balance ?? (totalPaid - totalFee);
    summary.appendRow([TextCellValue('项目'), TextCellValue('金额')]);
    summary.appendRow([TextCellValue('期初结转'), DoubleCellValue(openingBalance)]);
    summary.appendRow([TextCellValue('应收（出勤费用）'), DoubleCellValue(totalFee)]);
    summary.appendRow([TextCellValue('已收'), DoubleCellValue(totalPaid)]);
    summary.appendRow([
      TextCellValue('期内净变化'),
      DoubleCellValue(periodNetChange),
    ]);
    summary.appendRow([TextCellValue('期末余额'), DoubleCellValue(endingBalance)]);
    summary.appendRow([TextCellValue('')]);
    summary.appendRow([TextCellValue('缴费明细')]);
    for (final payment in payments) {
      summary.appendRow([
        TextCellValue('${payment.paymentDate} ${payment.note ?? ''}'),
        DoubleCellValue(payment.amount),
      ]);
    }

    excel.delete('Sheet1');

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel 编码失败');
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      buildStudentExportFileName(studentName: student.name, from: from, to: to),
    );
    await File(path).writeAsBytes(bytes);
    return path;
  }

  static Future<String> exportAllAttendance({
    required String from,
    required String to,
    required List<Attendance> records,
    required Map<String, String> studentNames,
  }) async {
    final excel = Excel.createExcel();

    _buildMatrixSheet(excel, records, studentNames);
    _buildDetailSheet(excel, records, studentNames);

    excel.delete('Sheet1');

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel 编码失败');
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      buildAttendanceExportFileName(from: from, to: to),
    );
    await File(path).writeAsBytes(bytes);
    return path;
  }

  @visibleForTesting
  static String buildStudentExportFileName({
    required String studentName,
    required String from,
    required String to,
  }) {
    final safeStudentName = _sanitizeFileNameSegment(
      studentName,
      fallback: 'student',
    );
    final safeFrom = _sanitizeFileNameSegment(from, fallback: 'from');
    final safeTo = _sanitizeFileNameSegment(to, fallback: 'to');
    return '${safeStudentName}_${safeFrom}_$safeTo.xlsx';
  }

  @visibleForTesting
  static String buildAttendanceExportFileName({
    required String from,
    required String to,
  }) {
    final safeFrom = _sanitizeFileNameSegment(from, fallback: 'from');
    final safeTo = _sanitizeFileNameSegment(to, fallback: 'to');
    return 'attendance_${safeFrom}_$safeTo.xlsx';
  }

  static void _buildMatrixSheet(
    Excel excel,
    List<Attendance> records,
    Map<String, String> studentNames,
  ) {
    final sheet = excel['出勤总览'];
    final timeSlotSet = <String>{};
    for (final record in records) {
      timeSlotSet.add('${record.startTime}-${record.endTime}');
    }
    final timeSlots = timeSlotSet.toList()..sort();

    final dateSet = <String>{};
    for (final record in records) {
      dateSet.add(record.date);
    }
    final dates = dateSet.toList()..sort();

    final grouped = <String, Map<String, List<String>>>{};
    for (final record in records) {
      if (record.status == 'absent') {
        continue;
      }
      final slot = '${record.startTime}-${record.endTime}';
      final name = studentNames[record.studentId] ?? record.studentId;
      grouped.putIfAbsent(record.date, () => <String, List<String>>{});
      grouped[record.date]!.putIfAbsent(slot, () => <String>[]);
      grouped[record.date]![slot]!.add(name);
    }

    final header = <CellValue>[
      TextCellValue('日期'),
      ...timeSlots.map((slot) => TextCellValue(slot)),
    ];
    sheet.appendRow(header);

    for (final date in dates) {
      final row = <CellValue>[
        TextCellValue(date),
        ...timeSlots.map((slot) {
          final names = grouped[date]?[slot];
          return TextCellValue(names != null ? names.join('、') : '');
        }),
      ];
      sheet.appendRow(row);
    }
  }

  static void _buildDetailSheet(
    Excel excel,
    List<Attendance> records,
    Map<String, String> studentNames,
  ) {
    final sheet = excel['出勤明细'];
    sheet.appendRow([
      TextCellValue('日期'),
      TextCellValue('开始时间'),
      TextCellValue('结束时间'),
      TextCellValue('学生'),
      TextCellValue('状态'),
      TextCellValue('费用'),
      TextCellValue('备注'),
    ]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0)).value =
        TextCellValue('课堂重点');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0)).value =
        TextCellValue('课后练习');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0)).value =
        TextCellValue('进步评分');

    final sortedRecords = List<Attendance>.from(records)
      ..sort((left, right) {
        final dateCompare = left.date.compareTo(right.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return left.startTime.compareTo(right.startTime);
      });

    for (final record in sortedRecords) {
      final name = studentNames[record.studentId] ?? record.studentId;
      sheet.appendRow([
        TextCellValue(record.date),
        TextCellValue(record.startTime),
        TextCellValue(record.endTime),
        TextCellValue(name),
        TextCellValue(statusLabel(record.status)),
        DoubleCellValue(record.feeAmount),
        TextCellValue(record.note ?? ''),
        TextCellValue(_formatLessonFocusTags(record)),
        TextCellValue(record.homePracticeNote ?? ''),
        TextCellValue(_formatProgressSummary(record)),
      ]);
    }
  }

  static String _formatLessonFocusTags(Attendance record) {
    if (record.lessonFocusTags.isEmpty) return '';
    return record.lessonFocusTags.join('、');
  }

  static String _formatProgressSummary(Attendance record) {
    final scores = record.progressScores;
    if (scores == null || scores.isEmpty) {
      return '';
    }

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
}
