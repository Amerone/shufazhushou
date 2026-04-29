import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/database/dao/attendance_dao.dart';
import 'package:moyun/core/database/dao/payment_dao.dart';
import 'package:moyun/core/database/dao/student_dao.dart';
import 'package:moyun/core/database/database_helper.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/payment.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/providers/attendance_provider.dart';
import 'package:moyun/core/providers/fee_summary_provider.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/core/providers/student_provider.dart';
import 'package:moyun/core/services/ai_analysis_note_codec.dart';
import 'package:moyun/features/export/screens/export_config_screen.dart';
import 'package:moyun/features/export/widgets/export_option_action_widgets.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('deleteExportTempFileForTesting removes temporary exports', () async {
    final directory = await Directory.systemTemp.createTemp('moyun_export_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/report.pdf');
    await file.writeAsString('temp');

    expect(await file.exists(), isTrue);

    await deleteExportTempFileForTesting(file.path);

    expect(await file.exists(), isFalse);
  });

  test(
    'cleanupExportTempFileForShareForTesting defers deletion after share',
    () async {
      final directory = await Directory.systemTemp.createTemp('moyun_export_');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final file = File('${directory.path}/report.pdf');
      await file.writeAsString('temp');

      await cleanupExportTempFileForShareForTesting(
        file.path,
        ShareResultStatus.success,
        deferredDelay: const Duration(milliseconds: 40),
      );

      expect(await file.exists(), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(await file.exists(), isFalse);
    },
  );

  test(
    'cleanupExportTempFileForShareForTesting deletes dismissed share immediately',
    () async {
      final directory = await Directory.systemTemp.createTemp('moyun_export_');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final file = File('${directory.path}/report.xlsx');
      await file.writeAsString('temp');

      await cleanupExportTempFileForShareForTesting(
        file.path,
        ShareResultStatus.dismissed,
      );

      expect(await file.exists(), isFalse);
    },
  );

  test('shouldTreatShareAsCompletedForTesting ignores dismissed share', () {
    expect(
      shouldTreatShareAsCompletedForTesting(ShareResultStatus.dismissed),
      isFalse,
    );
    expect(
      shouldTreatShareAsCompletedForTesting(ShareResultStatus.success),
      isTrue,
    );
    expect(
      shouldTreatShareAsCompletedForTesting(ShareResultStatus.unavailable),
      isTrue,
    );
  });

  testWidgets('shows saved AI analysis hint after enabling include toggle', (
    tester,
  ) async {
    final note = AiAnalysisNoteCodec.appendProgressAnalysis(
      existingNote: null,
      analysisText: 'SENTINEL_EXPORT_ANALYSIS',
      analyzedAt: DateTime(2026, 4, 1, 9),
    );
    final student = Student(
      id: 'student-1',
      name: 'Alice',
      pricePerClass: 200,
      status: 'active',
      note: note,
      createdAt: 1,
      updatedAt: 1,
    );

    await _pumpScreen(tester, student);

    expect(
      find.text(
        '\u5173\u95ed\u540e\uff0cPDF \u4e0d\u4f1a\u5305\u542b AI \u5206\u6790\u9875\u3002',
      ),
      findsOneWidget,
    );

    final aiAnalysisLabel = find.text('\u5305\u542b AI \u5206\u6790');
    await tester.ensureVisible(aiAnalysisLabel);
    await tester.tap(aiAnalysisLabel);
    await _settleUi(tester);

    expect(
      find.text(
        '\u4f1a\u4ece\u5b66\u751f\u5907\u6ce8\u4e2d\u63d0\u53d6\u5df2\u4fdd\u5b58\u7684 AI \u5206\u6790\uff0c\u5e76\u63d2\u5165 PDF\u3002',
      ),
      findsOneWidget,
    );
  });

  testWidgets('export switches can toggle from the whole row label', (
    tester,
  ) async {
    final note = AiAnalysisNoteCodec.appendProgressAnalysis(
      existingNote: null,
      analysisText: 'SENTINEL_EXPORT_ANALYSIS',
      analyzedAt: DateTime(2026, 4, 1, 9),
    );
    final student = Student(
      id: 'student-row-toggle',
      name: 'Dora',
      pricePerClass: 200,
      status: 'active',
      note: note,
      createdAt: 1,
      updatedAt: 1,
    );

    await _pumpScreen(tester, student);

    final aiAnalysisLabel = find.text('\u5305\u542b AI \u5206\u6790');
    await tester.ensureVisible(aiAnalysisLabel);
    await tester.tap(aiAnalysisLabel);
    await _settleUi(tester);

    expect(
      find.text(
        '\u4f1a\u4ece\u5b66\u751f\u5907\u6ce8\u4e2d\u63d0\u53d6\u5df2\u4fdd\u5b58\u7684 AI \u5206\u6790\uff0c\u5e76\u63d2\u5165 PDF\u3002',
      ),
      findsOneWidget,
    );
  });

  testWidgets('disables AI analysis toggle when note has no saved analysis', (
    tester,
  ) async {
    const student = Student(
      id: 'student-2',
      name: 'Bob',
      pricePerClass: 180,
      status: 'active',
      note: 'manual note only',
      createdAt: 1,
      updatedAt: 1,
    );

    await _pumpScreen(tester, student);

    expect(
      find.text(
        '\u6682\u65e0\u5df2\u4fdd\u5b58\u7684 AI \u5206\u6790\uff0c\u8bf7\u5148\u5728\u5b66\u751f\u8be6\u60c5\u9875\u4fdd\u5b58\u5206\u6790\u7ed3\u679c\u3002',
      ),
      findsOneWidget,
    );

    final aiSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(aiSwitch.onChanged, isNull);
  });

  testWidgets('close button exposes an accessible label', (tester) async {
    final semantics = tester.ensureSemantics();
    const student = Student(
      id: 'student-3',
      name: 'Cara',
      pricePerClass: 180,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    );

    try {
      await _pumpScreen(tester, student);

      expect(find.byTooltip('关闭导出配置'), findsOneWidget);
      final closeNode = tester.getSemantics(find.bySemanticsLabel('关闭导出配置'));
      expect(closeNode.flagsCollection.isButton, isTrue);
      expect(
        closeNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('parent snapshot failure says export can continue', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const student = Student(
      id: 'student-4',
      name: 'Dana',
      pricePerClass: 180,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    );

    try {
      await _pumpScreen(tester, student, failParentSnapshot: true);

      expect(
        find.text('家长端摘要加载失败，不影响导出。可直接继续预览、分享 PDF 或导出 Excel，或稍后重试。'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          '家长端摘要加载失败，不影响 PDF 预览、分享 PDF 或导出 Excel，可直接继续导出，或稍后重试',
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('export screen shows loading action notice during export', (
    tester,
  ) async {
    const student = Student(
      id: 'student-loading',
      name: 'Erin',
      pricePerClass: 180,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    );
    final pendingPayments = Completer<List<Payment>>();

    await _pumpScreen(tester, student, pendingPayments: pendingPayments);

    final exportExcelButton = find.text('导出 Excel');
    await tester.ensureVisible(exportExcelButton);
    await tester.tap(exportExcelButton);
    await tester.pump();

    expect(find.text('正在导出 Excel，请稍候'), findsOneWidget);
    expect(find.text('预览、分享和 Excel 导出会在当前任务完成后恢复。'), findsOneWidget);
    expect(find.text('Excel 导出中'), findsOneWidget);
    expect(find.text('导出 Excel 中...'), findsOneWidget);
    expect(find.text('等待中...'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(ExportActionPanel),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    pendingPayments.completeError(Exception('stop after loading assertion'));
    await tester.pumpAndSettle();
  });

  testWidgets('export ignores duplicate taps while an export is active', (
    tester,
  ) async {
    const student = Student(
      id: 'student-duplicate-export',
      name: 'Finn',
      pricePerClass: 180,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    );
    final pendingPayments = Completer<List<Payment>>();

    await _pumpScreen(tester, student, pendingPayments: pendingPayments);
    _resetExportCounters();

    final exportExcelButton = find.text('导出 Excel');
    await tester.ensureVisible(exportExcelButton);
    await tester.tap(exportExcelButton);
    await tester.tap(exportExcelButton);
    await tester.pump();

    expect(_FakePaymentDao.listQueryCount, 1);

    pendingPayments.completeError(Exception('stop after duplicate assertion'));
    await tester.pumpAndSettle();
  });

  testWidgets('export Excel starts data student and fee queries together', (
    tester,
  ) async {
    const student = Student(
      id: 'student-parallel-export',
      name: 'Gina',
      pricePerClass: 180,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    );
    final pendingPayments = Completer<List<Payment>>();

    await _pumpScreen(tester, student, pendingPayments: pendingPayments);
    _resetExportCounters();

    final exportExcelButton = find.text('导出 Excel');
    await tester.ensureVisible(exportExcelButton);
    await tester.tap(exportExcelButton);
    await tester.pump();
    await tester.pump();

    expect(_FakePaymentDao.listQueryCount, 1);
    expect(_FakeStudentDao.getByIdCount, 1);
    expect(_FakeAttendanceDao.totalFeeQueryCount, greaterThan(0));

    pendingPayments.completeError(Exception('stop after parallel assertion'));
    await tester.pumpAndSettle();
  });

  testWidgets('export action panel explains disabled loading state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportActionPanel(
            loading: true,
            onPreview: () {},
            onSharePdf: () {},
            onExportExcel: () {},
          ),
        ),
      ),
    );

    expect(find.text('正在生成导出文件，请稍候'), findsOneWidget);
    expect(find.text('预览、分享和 Excel 导出会在当前任务完成后恢复。'), findsOneWidget);
    expect(find.text('处理中...'), findsNWidgets(3));
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Student student, {
  bool failParentSnapshot = false,
  Completer<List<Payment>>? pendingPayments,
}) async {
  _FakeSettingsNotifier.seededSettings = const {
    'default_message_template': '',
    'default_watermark_enabled': 'true',
  };
  _FakeStudentNotifier.seededStudents = [StudentWithMeta(student, null)];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        attendanceDaoProvider.overrideWithValue(
          _FakeAttendanceDao(shouldFail: failParentSnapshot),
        ),
        paymentDaoProvider.overrideWithValue(
          _FakePaymentDao(pendingPayments: pendingPayments),
        ),
        studentDaoProvider.overrideWithValue(_FakeStudentDao(student)),
        studentProvider.overrideWith(_FakeStudentNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(body: ExportConfigScreen(studentId: student.id)),
      ),
    ),
  );
  await _settleUi(tester);
}

void _resetExportCounters() {
  _FakeAttendanceDao.totalFeeQueryCount = 0;
  _FakePaymentDao.listQueryCount = 0;
  _FakeStudentDao.getByIdCount = 0;
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {};

  @override
  Future<Map<String, String>> build() async => seededSettings;
}

class _FakeStudentDao extends StudentDao {
  static int getByIdCount = 0;

  final Student student;

  _FakeStudentDao(this.student) : super(DatabaseHelper.instance);

  @override
  Future<Student?> getById(String id) async {
    getByIdCount++;
    if (id != student.id) return null;
    return student;
  }
}

class _FakeAttendanceDao extends AttendanceDao {
  static int totalFeeQueryCount = 0;

  final bool shouldFail;

  _FakeAttendanceDao({this.shouldFail = false})
    : super(DatabaseHelper.instance);

  @override
  Future<List<Attendance>> getByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async {
    if (shouldFail) {
      return Future<List<Attendance>>.delayed(
        const Duration(milliseconds: 20),
        () => throw Exception('snapshot unavailable'),
      );
    }
    return const [];
  }

  @override
  Future<double> getTotalFeeByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async {
    totalFeeQueryCount++;
    return 0;
  }
}

class _FakePaymentDao extends PaymentDao {
  static int listQueryCount = 0;

  final Completer<List<Payment>>? pendingPayments;

  _FakePaymentDao({this.pendingPayments}) : super(DatabaseHelper.instance);

  @override
  Future<List<Payment>> getByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async {
    listQueryCount++;
    if (pendingPayments case final completer?) {
      return completer.future;
    }
    return const [];
  }

  @override
  Future<double> getTotalByStudentAndDateRange(
    String studentId,
    String? from,
    String? to,
  ) async {
    return 0;
  }
}

class _FakeStudentNotifier extends StudentNotifier {
  static List<StudentWithMeta> seededStudents = const [];

  @override
  Future<List<StudentWithMeta>> build() async => seededStudents;
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
