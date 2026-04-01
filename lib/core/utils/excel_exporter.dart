import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/payment.dart';
import '../../shared/constants.dart';

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
  }) async {
    final excel = Excel.createExcel();

    // Sheet1: 出勤明细
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
    for (final r in records) {
      final row = [
        TextCellValue(r.date),
        TextCellValue(r.startTime),
        TextCellValue(r.endTime),
        TextCellValue(statusLabel(r.status)),
        DoubleCellValue(r.priceSnapshot),
        DoubleCellValue(r.feeAmount),
        TextCellValue(r.note ?? ''),
      ];
      row.addAll([
        TextCellValue(_formatLessonFocusTags(r)),
        TextCellValue(r.homePracticeNote ?? ''),
        TextCellValue(_formatProgressSummary(r)),
      ]);
      detail.appendRow(row);
      // 条件格式：旷课行标红，请假行标灰
      final rowIdx = detail.maxRows - 1;
      final bgColor = r.status == 'absent'
          ? ExcelColor.fromHexString('#FFCCCC')
          : r.status == 'leave'
          ? ExcelColor.fromHexString('#EEEEEE')
          : null;
      if (bgColor != null) {
        for (int col = 0; col < row.length; col++) {
          final cell = detail.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx),
          );
          cell.cellStyle = CellStyle(backgroundColorHex: bgColor);
        }
      }
    }

    // Sheet2: 费用汇总
    final summary = excel['费用汇总'];
    final totalFee = records.fold<double>(0, (s, r) => s + r.feeAmount);
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    summary.appendRow([TextCellValue('项目'), TextCellValue('金额')]);
    summary.appendRow([TextCellValue('应收（出勤费用）'), DoubleCellValue(totalFee)]);
    summary.appendRow([TextCellValue('已收'), DoubleCellValue(totalPaid)]);
    summary.appendRow([
      TextCellValue('余额'),
      DoubleCellValue(totalPaid - totalFee),
    ]);
    summary.appendRow([TextCellValue('')]);
    summary.appendRow([TextCellValue('缴费明细')]);
    for (final pay in payments) {
      summary.appendRow([
        TextCellValue('${pay.paymentDate} ${pay.note ?? ''}'),
        DoubleCellValue(pay.amount),
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

  /// 导出指定时间范围内所有人的出勤情况
  static Future<String> exportAllAttendance({
    required String from,
    required String to,
    required List<Attendance> records,
    required Map<String, String> studentNames,
  }) async {
    final excel = Excel.createExcel();

    // Sheet1: 日期×时间段矩阵
    _buildMatrixSheet(excel, records, studentNames);

    // Sheet2: 逐条明细
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
    // 收集所有唯一时间段，按开始时间排序
    final timeSlotSet = <String>{};
    for (final r in records) {
      timeSlotSet.add('${r.startTime}-${r.endTime}');
    }
    final timeSlots = timeSlotSet.toList()..sort();

    // 收集所有唯一日期，排序
    final dateSet = <String>{};
    for (final r in records) {
      dateSet.add(r.date);
    }
    final dates = dateSet.toList()..sort();

    // 构建 (date, slot) -> [names] 映射
    final map = <String, Map<String, List<String>>>{};
    for (final r in records) {
      if (r.status == 'absent') continue;
      final slot = '${r.startTime}-${r.endTime}';
      final name = studentNames[r.studentId] ?? r.studentId;
      map.putIfAbsent(r.date, () => {});
      map[r.date]!.putIfAbsent(slot, () => []);
      map[r.date]![slot]!.add(name);
    }

    // 表头
    final header = <CellValue>[
      TextCellValue('日期'),
      ...timeSlots.map((s) => TextCellValue(s)),
    ];
    sheet.appendRow(header);

    // 数据行
    for (final date in dates) {
      final row = <CellValue>[
        TextCellValue(date),
        ...timeSlots.map((slot) {
          final names = map[date]?[slot];
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

    final sorted = List<Attendance>.from(records)
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        if (d != 0) return d;
        return a.startTime.compareTo(b.startTime);
      });

    for (final r in sorted) {
      final name = studentNames[r.studentId] ?? r.studentId;
      sheet.appendRow([
        TextCellValue(r.date),
        TextCellValue(r.startTime),
        TextCellValue(r.endTime),
        TextCellValue(name),
        TextCellValue(statusLabel(r.status)),
        DoubleCellValue(r.feeAmount),
        TextCellValue(r.note ?? ''),
        TextCellValue(_formatLessonFocusTags(r)),
        TextCellValue(r.homePracticeNote ?? ''),
        TextCellValue(_formatProgressSummary(r)),
      ]);
    }
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
