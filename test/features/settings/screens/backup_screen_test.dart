import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/utils/backup_helper.dart';
import 'package:moyun/features/settings/screens/backup_screen.dart';

void main() {
  test('backup risk copy keeps passphrase and restore requirements', () {
    expect(backupCreateConfirmMessage, contains('口令'));
    expect(backupCreatePassphraseDescription, contains('同一口令'));
    expect(backupCreateSuccessMessage, contains('同一口令'));
    expect(
      backupExistingSharePassphraseDescription,
      allOf(contains('加密分享文件'), contains('恢复需同一口令')),
    );
    expect(backupExistingShareSuccessMessage, contains('恢复需同一口令'));
    expect(
      backupRestoreFromPickerConfirmMessage,
      allOf(contains('覆盖'), contains('不可撤销'), contains('自动生成本机备份')),
    );
    expect(
      backupRestoreRecordConfirmMessage('backup.db'),
      allOf(contains('backup.db'), contains('覆盖'), contains('不可撤销')),
    );
  });

  testWidgets('passphrase visibility control exposes stateful semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var obscure = true;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(
                  child: buildBackupPassphraseVisibilityToggleForTesting(
                    obscure: obscure,
                    showTooltip: '显示备份口令',
                    hideTooltip: '隐藏备份口令',
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              );
            },
          ),
        ),
      );

      final showButton = find.byTooltip('显示备份口令');
      expect(showButton, findsOneWidget);
      _expectTappableButtonSemantics(tester, showButton);
      _expectMinTapTarget(tester, showButton);

      await tester.tap(showButton);
      await tester.pump();

      final hideButton = find.byTooltip('隐藏备份口令');
      expect(hideButton, findsOneWidget);
      _expectTappableButtonSemantics(tester, hideButton);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('backup restore action describes target and risk', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var restoreCount = 0;

    try {
      final fileName = BackupHelper.buildBackupFileName(
        DateTime(2026, 4, 1, 9, 5, 7),
      );
      final record = BackupRecord(
        path: 'C:/tmp/$fileName',
        fileName: fileName,
        modifiedAt: DateTime(2026, 4, 1, 9, 5, 7),
        sizeInBytes: 128,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: buildBackupRestoreActionForTesting(
                record: record,
                onRestore: () => restoreCount++,
              ),
            ),
          ),
        ),
      );

      final restoreButton = find.bySemanticsLabel('恢复备份 $fileName');
      expect(restoreButton, findsOneWidget);

      final node = tester.getSemantics(restoreButton);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.hint, '会先显示确认提示，确认后覆盖当前全部数据');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.widgetWithText(OutlinedButton, '恢复'));

      expect(restoreCount, 1);
    } finally {
      semantics.dispose();
    }
  });
}

void _expectTappableButtonSemantics(WidgetTester tester, Finder finder) {
  final semanticsData = tester.getSemantics(finder).getSemanticsData();
  expect(semanticsData.flagsCollection.isButton, isTrue);
  expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);
}

void _expectMinTapTarget(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}
