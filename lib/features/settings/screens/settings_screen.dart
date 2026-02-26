import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/class_template_provider.dart';
import '../../../core/providers/contribution_provider.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/insight_provider.dart';
import '../../../core/providers/metrics_provider.dart';
import '../../../core/providers/revenue_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/seed_test_data.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (settings) {
          final lastBackupMs = int.tryParse(settings['last_backup_at'] ?? '');
          final isOverdue = lastBackupMs == null ||
              DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastBackupMs)).inDays >=
                  kBackupWarningDays;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ListTile(
                title: const Text('老师姓名'),
                subtitle: Text(settings['teacher_name'] ?? kDefaultTeacherName),
                trailing: const Icon(Icons.edit),
                onTap: () => _editTeacherName(context, ref, settings['teacher_name'] ?? kDefaultTeacherName),
              ),
              const Divider(),
              ListTile(
                title: const Text('数据备份'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOverdue) const Icon(Icons.warning_amber, color: kOrange, size: 18),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => context.push('/settings/backup'),
              ),
              ListTile(
                title: const Text('课堂模板'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/templates'),
              ),
              ListTile(
                title: const Text('签名管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/signature'),
              ),
              ListTile(
                title: const Text('压角章'),
                subtitle: Text(settings['seal_text'] ?? kDefaultSealText),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/seal'),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('导出 PDF 默认启用水印'),
                value: settings['default_watermark_enabled'] != 'false',
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).set('default_watermark_enabled', v.toString());
                },
              ),
              ListTile(
                title: const Text('默认寄语'),
                subtitle: Text(settings['default_message_template'] ?? '未设置'),
                trailing: const Icon(Icons.edit),
                onTap: () => _editMessage(context, ref, settings['default_message_template'] ?? ''),
              ),
              const Divider(),
              ListTile(
                title: const Text('下载导入模板'),
                trailing: const Icon(Icons.download),
                onTap: () => _downloadTemplate(context),
              ),
              const Divider(),
              ListTile(
                title: const Text('生成测试数据'),
                subtitle: const Text('插入 20 名学生 x 250 条出勤记录'),
                trailing: const Icon(Icons.science),
                onTap: () => _seedTestData(context, ref),
              ),
              ListTile(
                title: Text('清除所有数据', style: TextStyle(color: kRed)),
                subtitle: const Text('删除全部学生、出勤、缴费等记录'),
                trailing: const Icon(Icons.delete_forever, color: kRed),
                onTap: () => _clearAllData(context, ref),
              ),
              const Divider(),
              const ListTile(
                title: Text('关于'),
                subtitle: Text('书法助手 v1.0.0'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editTeacherName(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('老师姓名'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).set('teacher_name', ctrl.text.trim());
              Navigator.pop(dialogCtx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _editMessage(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('默认寄语'),
        content: TextField(controller: ctrl, maxLines: 4, maxLength: 200, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).set('default_message_template', ctrl.text.trim());
              Navigator.pop(dialogCtx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _seedTestData(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppToast.showConfirm(context, '将插入 20 名学生和约 5000 条出勤记录，确定继续吗？');
    if (!confirmed) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await SeedTestData.run(db);
      _invalidateAll(ref);
      if (context.mounted) AppToast.showSuccess(context, '测试数据已生成');
    } catch (e) {
      if (context.mounted) AppToast.showError(context, e.toString());
    }
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppToast.showConfirm(context, '将删除所有数据且不可恢复，确定继续吗？');
    if (!confirmed) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('attendance');
      await db.delete('payments');
      await db.delete('dismissed_insights');
      await db.delete('class_templates');
      await db.delete('settings');
      await db.delete('students');
      _invalidateAll(ref);
      if (context.mounted) AppToast.showSuccess(context, '所有数据已清除');
    } catch (e) {
      if (context.mounted) AppToast.showError(context, e.toString());
    }
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(studentProvider);
    ref.invalidate(attendanceProvider);
    ref.invalidate(feeSummaryProvider);
    ref.invalidate(metricsProvider);
    ref.invalidate(revenueProvider);
    ref.invalidate(contributionProvider);
    ref.invalidate(insightProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(classTemplateProvider);
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        TextCellValue('姓名'),
        TextCellValue('家长姓名'),
        TextCellValue('家长电话'),
        TextCellValue('单价'),
      ]);

      final bytes = excel.encode();
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, '学生导入模板.xlsx'));
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (context.mounted) AppToast.showError(context, e.toString());
    }
  }
}
