import 'dart:io';

import 'dart:async';

import 'package:excel/excel.dart' hide Border;
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
import '../../../shared/utils/interaction_feedback.dart';
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
            const PageHeader(
              title: '设置中心',
              subtitle: '管理教师信息、导出模板和本地数据备份。',
            ),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (settings) {
                  final lastBackupMs = int.tryParse(settings['last_backup_at'] ?? '');
                  final isOverdue = lastBackupMs == null ||
                      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastBackupMs)).inDays >=
                          kBackupWarningDays;
                  final teacherName = settings['teacher_name'] ?? kDefaultTeacherName;
                  final watermarkEnabled = settings['default_watermark_enabled'] != 'false';
                  final hapticsEnabled =
                      settings[InteractionFeedback.hapticsEnabledKey] != 'false';
                  final soundEnabled =
                      settings[InteractionFeedback.soundEnabledKey] == 'true';
                  final hasDefaultMessage = settings['default_message_template']?.trim().isNotEmpty == true;
                  final hasSignature = settings['signature_path']?.trim().isNotEmpty == true;
                  final hasCustomTeacherName = teacherName.trim().isNotEmpty && teacherName != kDefaultTeacherName;
                  final priority = _resolvePriority(
                    isOverdue: isOverdue,
                    hasDefaultMessage: hasDefaultMessage,
                    hasSignature: hasSignature,
                    hasCustomTeacherName: hasCustomTeacherName,
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                    children: [
                      if (priority != null) ...[
                        _PriorityBanner(
                          title: priority.title,
                          description: priority.description,
                          actionLabel: priority.actionLabel,
                          color: priority.color,
                          onTap: () => _handlePriorityTap(priority.action, context),
                        ),
                        const SizedBox(height: 16),
                      ],
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: kPrimaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.tune_outlined, color: kPrimaryBlue),
                                ),
                                SizedBox(
                                  width: versionStr.isEmpty ? 220 : 160,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '当前配置概览',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '先看关键状态，再进入对应分区调整教师资料、模板和备份。',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (versionStr.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.68),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: kInkSecondary.withValues(alpha: 0.16)),
                                    ),
                                    child: Text(
                                      'v$versionStr',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: kPrimaryBlue,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 720 ? 4 : 2;
                                final itemWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SettingsSnapshot(
                                        icon: Icons.person_outline,
                                        label: '教师抬头',
                                        value: teacherName,
                                        color: kPrimaryBlue,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SettingsSnapshot(
                                        icon: Icons.backup_outlined,
                                        label: '最近备份',
                                        value: _backupSummaryLabel(lastBackupMs),
                                        color: isOverdue ? kOrange : kGreen,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SettingsSnapshot(
                                        icon: Icons.water_drop_outlined,
                                        label: 'PDF 水印',
                                        value: watermarkEnabled ? '已开启' : '已关闭',
                                        color: watermarkEnabled ? kPrimaryBlue : kInkSecondary,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SettingsSnapshot(
                                        icon: Icons.message_outlined,
                                        label: '默认寄语',
                                        value: hasDefaultMessage ? '已配置' : '未设置',
                                        color: hasDefaultMessage ? kSealRed : kOrange,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            const _SettingsSectionTitle(
                              title: '常用入口',
                              subtitle: '把最常打开的设置集中放在顶部，减少来回查找。',
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 720 ? 4 : 2;
                                final itemWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SettingsShortcutCard(
                                        icon: Icons.backup_outlined,
                                        title: '数据备份',
                                        subtitle: isOverdue ? '建议更新' : '查看记录',
                                        color: isOverdue ? kOrange : kPrimaryBlue,
                                        onTap: () => context.push('/settings/backup'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SettingsShortcutCard(
                                        icon: Icons.draw_outlined,
                                        title: '签名管理',
                                        subtitle: hasSignature ? '已配置' : '待上传',
                                        color: hasSignature ? kGreen : kSealRed,
                                        onTap: () => context.push('/settings/signature'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SettingsShortcutCard(
                                        icon: Icons.view_quilt_outlined,
                                        title: '课堂模板',
                                        subtitle: '时段与课程',
                                        color: kPrimaryBlue,
                                        onTap: () => context.push('/settings/templates'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SettingsShortcutCard(
                                        icon: Icons.approval_outlined,
                                        title: '印章样式',
                                        subtitle: settings['seal_text']?.isNotEmpty == true ? '已设置' : '待配置',
                                        color: kSealRed,
                                        onTap: () => context.push('/settings/seal'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SettingsShortcutCard(
                                        icon: Icons.psychology_alt_outlined,
                                        title: 'AI 视觉',
                                        subtitle: settings['qwen_api_key']?.trim().isNotEmpty == true ? 'Qwen 已配置' : '待接入',
                                        color: settings['qwen_api_key']?.trim().isNotEmpty == true ? kGreen : kPrimaryBlue,
                                        onTap: () => context.push('/settings/ai'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SettingsSectionTitle(
                        title: '教师资料',
                        subtitle: '影响首页抬头、导出报告与对外展示的基础信息。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.person_outline,
                              title: '教师姓名',
                              subtitle: settings['teacher_name'] ?? kDefaultTeacherName,
                              trailing: const Icon(Icons.edit_outlined, size: 20),
                              onTap: () => _editTeacherName(settings['teacher_name'] ?? kDefaultTeacherName),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SettingsSectionTitle(
                        title: '资料与模板',
                        subtitle: '维护备份、课堂模板、签名和印章等常用资产。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.backup_outlined,
                              title: '数据备份',
                              subtitle: isOverdue ? '建议立即执行一次本地备份' : '查看最近备份并导出备份文件',
                              warning: isOverdue,
                              onTap: () => context.push('/settings/backup'),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _SettingsTile(
                              icon: Icons.view_quilt_outlined,
                              title: '课堂模板',
                              subtitle: '管理常用课程模板和上课时段',
                              onTap: () => context.push('/settings/templates'),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _SettingsTile(
                              icon: Icons.draw_outlined,
                              title: '签名管理',
                              subtitle: '维护导出报告中的签名图片',
                              onTap: () => context.push('/settings/signature'),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _SettingsTile(
                              icon: Icons.approval_outlined,
                              title: '印章样式',
                              subtitle: settings['seal_text'] ?? kDefaultSealText,
                              onTap: () => context.push('/settings/seal'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SettingsSectionTitle(
                        title: '导出与沟通',
                        subtitle: '决定 PDF 报告的默认效果，以及家长沟通文案的起点。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingsSwitchTile(
                              value: watermarkEnabled,
                              icon: Icons.water_drop_outlined,
                              title: '默认启用 PDF 水印',
                              subtitle: '导出报告时自动附加印章与标识',
                              onChanged: (value) {
                                ref.read(settingsProvider.notifier).set('default_watermark_enabled', value.toString());
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _SettingsTile(
                              icon: Icons.message_outlined,
                              title: '默认寄语',
                              subtitle: settings['default_message_template']?.isNotEmpty == true
                                  ? settings['default_message_template']!
                                  : '尚未设置默认寄语',
                              trailing: const Icon(Icons.edit_outlined, size: 20),
                              onTap: () => _editMessage(settings['default_message_template'] ?? ''),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SettingsSectionTitle(
                        title: '沉浸反馈',
                        subtitle: '让翻页、保存与导出在视觉之外，也保留一点纸墨手感。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingsSwitchTile(
                              value: hapticsEnabled,
                              icon: Icons.vibration_outlined,
                              title: '启用触感反馈',
                              subtitle: '保存、确认、时间滚轮和关键选择时给出轻微震动。',
                              onChanged: (value) {
                                ref.read(settingsProvider.notifier).set(
                                      InteractionFeedback.hapticsEnabledKey,
                                      value.toString(),
                                    );
                                if (value) {
                                  unawaited(InteractionFeedback.selection(context));
                                }
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _SettingsSwitchTile(
                              value: soundEnabled,
                              icon: Icons.music_note_outlined,
                              title: '启用轻音反馈',
                              subtitle: '页面切换与导出完成时播放极轻的系统提示音。',
                              onChanged: (value) {
                                ref.read(settingsProvider.notifier).set(
                                      InteractionFeedback.soundEnabledKey,
                                      value.toString(),
                                    );
                                unawaited(InteractionFeedback.selection(context));
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SettingsSectionTitle(
                        title: 'AI 扩展',
                        subtitle: '预留视觉模型与远端能力配置，保持 UI 与远端网关解耦。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.psychology_alt_outlined,
                              title: 'Qwen 视觉模型',
                              subtitle: settings['qwen_model']?.trim().isNotEmpty == true
                                  ? settings['qwen_model']!
                                  : '计划调用 Qwen3-VL-Plus',
                              onTap: () => context.push('/settings/ai'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SettingsSectionTitle(
                        title: '导入工具',
                        subtitle: '批量录入前可先下载标准模板，减少字段缺失或顺序错误。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.download_outlined,
                              title: '下载学生导入模板',
                              subtitle: '生成一个 Excel 模板，方便批量录入学生信息',
                              onTap: _downloadTemplate,
                            ),
                          ],
                        ),
                      ),
                      if (_devMode) ...[
                        const SizedBox(height: 20),
                        const _SettingsSectionTitle(
                          title: '开发者工具',
                          subtitle: '用于本地演示、压测和初始化环境，操作前请确认风险。',
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              _SettingsTile(
                                icon: Icons.science_outlined,
                                title: '生成测试数据',
                                subtitle: '插入 20 名学生与大量出勤记录，用于压力验证',
                                onTap: _seedTestData,
                              ),
                              const Divider(height: 1, indent: 16, endIndent: 16),
                              _SettingsTile(
                                icon: Icons.delete_forever_outlined,
                                title: '清空全部数据',
                                subtitle: '删除学生、出勤、缴费和模板等所有本地记录',
                                titleColor: kRed,
                                iconColor: kRed,
                                onTap: _clearAllData,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const _SettingsSectionTitle(
                        title: '关于应用',
                        subtitle: '查看版本信息，并保留隐藏的开发者模式入口。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.info_outline,
                              title: '书法助手',
                              subtitle: _devMode
                                  ? '版本 $versionStr · 开发者模式已开启'
                                  : '版本 $versionStr · 连续点击 5 次可开启开发者模式',
                              onTap: () {
                                if (_devMode) return;
                                _versionTapCount++;
                                if (_versionTapCount >= 5) {
                                  setState(() => _devMode = true);
                                  AppToast.showSuccess(context, '已进入开发者模式');
                                }
                              },
                            ),
                          ],
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
    _showTextEditSheet(
      title: '教师姓名',
      hintText: '请输入教师姓名',
      initialValue: current,
      maxLines: 1,
      allowEmpty: false,
      onSave: (value) => ref.read(settingsProvider.notifier).set('teacher_name', value),
    );
  }

  void _editMessage(String current) {
    _showTextEditSheet(
      title: '默认寄语',
      hintText: '请输入导出报告时默认使用的寄语',
      initialValue: current,
      maxLines: 4,
      maxLength: 200,
      allowEmpty: true,
      onSave: (value) => ref.read(settingsProvider.notifier).set('default_message_template', value),
    );
  }

  void _showTextEditSheet({
    required String title,
    required String hintText,
    required String initialValue,
    required Future<void> Function(String value) onSave,
    int maxLines = 1,
    int? maxLength,
    bool allowEmpty = false,
  }) {
    final ctrl = TextEditingController(text: initialValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.zero,
          child: GlassCard(
            margin: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + MediaQuery.of(sheetCtx).padding.bottom + 16,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: kInkSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: Theme.of(sheetCtx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '修改后会立即应用到后续导出和页面展示中。',
                  style: Theme.of(sheetCtx).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: ctrl,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: title,
                    hintText: hintText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.56),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final value = ctrl.text.trim();
                    if (!allowEmpty && value.isEmpty) {
                      AppToast.showError(sheetCtx, '$title不能为空');
                      return;
                    }
                    await onSave(value);
                    await InteractionFeedback.seal(sheetCtx);
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                  },
                  child: const Text('保存修改'),
                ),
              ],
            ),
          ),
        ),
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
    final confirmed = await AppToast.showConfirm(context, '将删除所有本地数据且不可恢复，确定继续吗？');
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
      await ref.read(sensitiveSettingsStoreProvider).clearAll();
      invalidateAll(ref);
      if (mounted) AppToast.showSuccess(context, '全部数据已清空');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        TextCellValue('学生姓名'),
        TextCellValue('家长姓名'),
        TextCellValue('家长电话'),
        TextCellValue('课时单价'),
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

  String _backupSummaryLabel(int? lastBackupMs) {
    if (lastBackupMs == null) return '未创建';
    final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastBackupMs);
    final days = DateTime.now().difference(lastBackup).inDays;
    if (days <= 0) return '今天';
    return '$days 天前';
  }

  _PrioritySuggestion? _resolvePriority({
    required bool isOverdue,
    required bool hasDefaultMessage,
    required bool hasSignature,
    required bool hasCustomTeacherName,
  }) {
    if (isOverdue) {
      return const _PrioritySuggestion(
        title: '建议优先更新本地备份',
        description: '距离上次备份时间较久，先保留最新数据副本，再继续调整模板和导出配置更稳妥。',
        actionLabel: '前往备份',
        action: _PriorityAction.backup,
        color: kOrange,
      );
    }
    if (!hasSignature) {
      return const _PrioritySuggestion(
        title: '建议补充教师签名',
        description: '签名会直接影响 PDF 报告落款效果，上传后导出资料会更完整。',
        actionLabel: '上传签名',
        action: _PriorityAction.signature,
        color: kSealRed,
      );
    }
    if (!hasDefaultMessage) {
      return const _PrioritySuggestion(
        title: '可以补充默认寄语',
        description: '先设置一份默认寄语，之后导出报告时可以直接复用，减少重复输入。',
        actionLabel: '编辑寄语',
        action: _PriorityAction.message,
        color: kPrimaryBlue,
      );
    }
    if (!hasCustomTeacherName) {
      return const _PrioritySuggestion(
        title: '建议更新教师抬头',
        description: '使用真实教师姓名后，首页、报告和印章相关资料会保持一致。',
        actionLabel: '修改姓名',
        action: _PriorityAction.teacher,
        color: kGreen,
      );
    }
    return null;
  }

  void _handlePriorityTap(_PriorityAction action, BuildContext context) {
    switch (action) {
      case _PriorityAction.backup:
        context.push('/settings/backup');
        break;
      case _PriorityAction.signature:
        context.push('/settings/signature');
        break;
      case _PriorityAction.message:
        _editMessage(ref.read(settingsProvider).valueOrNull?['default_message_template'] ?? '');
        break;
      case _PriorityAction.teacher:
        _editTeacherName(ref.read(settingsProvider).valueOrNull?['teacher_name'] ?? kDefaultTeacherName);
        break;
    }
  }
}

enum _PriorityAction {
  backup,
  signature,
  message,
  teacher,
}

class _PrioritySuggestion {
  final String title;
  final String description;
  final String actionLabel;
  final _PriorityAction action;
  final Color color;

  const _PrioritySuggestion({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.action,
    required this.color,
  });
}

class _PriorityBanner extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final Color color;
  final VoidCallback onTap;

  const _PriorityBanner({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final buttonWidth = compact ? constraints.maxWidth : 120.0;
          final contentWidth = compact ? constraints.maxWidth : constraints.maxWidth - buttonWidth - 14;

          return Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: contentWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.priority_high_outlined, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: buttonWidth,
                child: FilledButton.tonalIcon(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.arrow_forward_outlined, size: 18),
                  label: Text(actionLabel),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SettingsSectionTitle({
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _SettingsSnapshot extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SettingsSnapshot({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SettingsShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool warning;
  final Color? titleColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.warning = false,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedTitleColor = titleColor ?? theme.textTheme.titleSmall?.color;
    final resolvedIconColor = iconColor ?? (warning ? kOrange : kPrimaryBlue);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: resolvedIconColor!.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: resolvedIconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: resolvedTitleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ?? const Icon(Icons.chevron_right, size: 20, color: kInkSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final bool value;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: kPrimaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: kPrimaryBlue),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Switch(
                        value: value,
                        activeThumbColor: kPrimaryBlue,
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: kPrimaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: kPrimaryBlue),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: value,
                      activeThumbColor: kPrimaryBlue,
                      onChanged: onChanged,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
