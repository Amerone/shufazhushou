import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/package_info_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/seed_test_data.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTapCount = 0;
  bool _devMode = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final pkgInfo = ref.watch(packageInfoProvider);
    final versionStr = pkgInfo.whenOrNull(data: (info) => info.version) ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            const PageHeader(title: '设置'),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (settings) {
                  final lastBackupMs = int.tryParse(settings['last_backup_at'] ?? '');
                  final isOverdue = lastBackupMs == null ||
                      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastBackupMs)).inDays >=
                          kBackupWarningDays;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('老师姓名'),
                              subtitle: Text(settings['teacher_name'] ?? kDefaultTeacherName),
                              trailing: const Icon(Icons.edit, size: 20),
                              onTap: () => _editTeacherName(settings['teacher_name'] ?? kDefaultTeacherName),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('数据备份'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isOverdue) const Icon(Icons.warning_amber, color: kOrange, size: 18),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 20, color: kInkSecondary),
                                ],
                              ),
                              onTap: () => context.push('/settings/backup'),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              title: const Text('课堂模板'),
                              trailing: const Icon(Icons.chevron_right, size: 20, color: kInkSecondary),
                              onTap: () => context.push('/settings/templates'),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              title: const Text('签名管理'),
                              trailing: const Icon(Icons.chevron_right, size: 20, color: kInkSecondary),
                              onTap: () => context.push('/settings/signature'),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              title: const Text('压角章'),
                              subtitle: Text(settings['seal_text'] ?? kDefaultSealText),
                              trailing: const Icon(Icons.chevron_right, size: 20, color: kInkSecondary),
                              onTap: () => context.push('/settings/seal'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('导出 PDF 默认启用水印'),
                              value: settings['default_watermark_enabled'] != 'false',
                              activeThumbColor: kPrimaryBlue,
                              onChanged: (v) {
                                ref.read(settingsProvider.notifier).set('default_watermark_enabled', v.toString());
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              title: const Text('默认寄语'),
                              subtitle: Text(settings['default_message_template'] ?? '未设置'),
                              trailing: const Icon(Icons.edit, size: 20),
                              onTap: () => _editMessage(settings['default_message_template'] ?? ''),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('下载导入模板'),
                              trailing: const Icon(Icons.download, size: 20),
                              onTap: () => _downloadTemplate(),
                            ),
                          ],
                        ),
                      ),
                      if (_devMode) ...[
                        const SizedBox(height: 16),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              ListTile(
                                title: const Text('生成测试数据'),
                                subtitle: const Text('插入 20 名学生 x 250 条出勤记录'),
                                trailing: const Icon(Icons.science, size: 20),
                                onTap: () => _seedTestData(),
                              ),
                              const Divider(height: 1, indent: 16, endIndent: 16),
                              ListTile(
                                title: const Text('清除所有数据', style: TextStyle(color: kRed)),
                                subtitle: const Text('删除全部学生、出勤、缴费等记录'),
                                trailing: const Icon(Icons.delete_forever, color: kRed, size: 20),
                                onTap: () => _clearAllData(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: const Text('关于'),
                          subtitle: Text('书法助手 v$versionStr'),
                          onTap: () {
                            if (_devMode) return;
                            _versionTapCount++;
                            if (_versionTapCount >= 5) {
                              setState(() => _devMode = true);
                              AppToast.showSuccess(context, '已进入开发者模式');
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editTeacherName(String current) {
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

  void _editMessage(String current) {
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

  Future<void> _seedTestData() async {
    final confirmed = await AppToast.showConfirm(context, '将插入 20 名学生和约 5000 条出勤记录，确定继续吗？');
    if (!confirmed) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await SeedTestData.run(db);
      invalidateAll(ref);
      if (mounted) AppToast.showSuccess(context, '测试数据已生成');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await AppToast.showConfirm(context, '将删除所有数据且不可恢复，确定继续吗？');
    if (!confirmed) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete('attendance');
        await txn.delete('payments');
        await txn.delete('dismissed_insights');
        await txn.delete('class_templates');
        await txn.delete('settings');
        await txn.delete('students');
      });
      invalidateAll(ref);
      if (mounted) AppToast.showSuccess(context, '所有数据已清除');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    }
  }

  Future<void> _downloadTemplate() async {
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
      if (mounted) AppToast.showError(context, e.toString());
    }
  }
}
