import 'dart:io';

import 'dart:async';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
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
import '../../../core/services/attendance_artwork_storage_service.dart';
import '../../../core/utils/seed_test_data.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/settings_overview_panel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTapCount = 0;
  bool _devMode = false;
  bool _showScrollToTop = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showScrollToTop = _scrollController.hasClients
        ? _scrollController.offset > 260
        : false;
    if (showScrollToTop != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = showScrollToTop);
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await InteractionFeedback.selection(context);
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final pkgInfo = ref.watch(packageInfoProvider);
    final versionStr = pkgInfo.whenOrNull(data: (info) => info.version) ?? '';
    final viewPaddingBottom = MediaQuery.of(context).viewPadding.bottom;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final horizontalPadding = MediaQuery.sizeOf(context).width < 390
        ? 16.0
        : 24.0;

    final scrollToTopAction = ExcludeSemantics(
      excluding: !_showScrollToTop,
      child: IgnorePointer(
        ignoring: !_showScrollToTop,
        child: Padding(
          padding: EdgeInsets.only(bottom: viewPaddingBottom + 80),
          child: Semantics(
            button: true,
            label: '返回设置页顶部',
            child: FloatingActionButton.small(
              heroTag: 'settings-scroll-top',
              onPressed: _scrollToTop,
              tooltip: '回到顶部',
              backgroundColor: Colors.white.withValues(alpha: 0.92),
              foregroundColor: kPrimaryBlue,
              elevation: 0,
              child: const Icon(Icons.vertical_align_top_outlined),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            const PageHeader(title: '设置中心'),
            Expanded(
              child: AsyncValueWidget<Map<String, String>>(
                value: settingsAsync,
                onRetry: () => ref.invalidate(settingsProvider),
                builder: (settings) {
                  final lastBackupMs = int.tryParse(
                    settings['last_backup_at'] ?? '',
                  );
                  final isOverdue =
                      lastBackupMs == null ||
                      DateTime.now()
                              .difference(
                                DateTime.fromMillisecondsSinceEpoch(
                                  lastBackupMs,
                                ),
                              )
                              .inDays >=
                          kBackupWarningDays;
                  final teacherName =
                      settings['teacher_name'] ?? kDefaultTeacherName;
                  final institutionName =
                      settings['institution_name'] ?? kDefaultInstitutionName;
                  final watermarkEnabled =
                      settings['default_watermark_enabled'] != 'false';
                  final hapticsEnabled =
                      settings[InteractionFeedback.hapticsEnabledKey] !=
                      'false';
                  final soundEnabled =
                      settings[InteractionFeedback.soundEnabledKey] == 'true';
                  final hasDefaultMessage =
                      settings['default_message_template']?.trim().isNotEmpty ==
                      true;
                  final hasSignature =
                      settings['signature_path']?.trim().isNotEmpty == true;
                  final hasCustomTeacherName =
                      teacherName.trim().isNotEmpty &&
                      teacherName != kDefaultTeacherName;
                  final priority = _resolvePriority(
                    isOverdue: isOverdue,
                    hasDefaultMessage: hasDefaultMessage,
                    hasSignature: hasSignature,
                    hasCustomTeacherName: hasCustomTeacherName,
                  );
                  final setupReadyCount = [
                    hasCustomTeacherName,
                    hasSignature,
                    hasDefaultMessage,
                    !isOverdue,
                  ].where((item) => item).length;
                  final setupCompletion = setupReadyCount / 4;

                  return ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      4,
                      horizontalPadding,
                      120,
                    ),
                    children: [
                      if (priority != null) ...[
                        _PriorityBanner(
                          title: priority.title,
                          description: priority.description,
                          actionLabel: priority.actionLabel,
                          color: priority.color,
                          onTap: () =>
                              _handlePriorityTap(priority.action, context),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SettingsOverviewPanel(
                        version: versionStr,
                        teacherName: teacherName,
                        backupSummary: _backupSummaryLabel(lastBackupMs),
                        isBackupOverdue: isOverdue,
                        watermarkEnabled: watermarkEnabled,
                        hasDefaultMessage: hasDefaultMessage,
                        setupReadyCount: setupReadyCount,
                        setupCompletion: setupCompletion,
                        priorityHint: priority == null
                            ? '当前导出与备份配置已经比较完整，可以继续微调细节。'
                            : '下一步建议先处理“${priority.actionLabel}”，这样后续导出和沟通会更顺手。',
                        hasSignature: hasSignature,
                        hasSeal: settings['seal_text']?.isNotEmpty == true,
                        hasAiConfig:
                            settings['qwen_api_key']?.trim().isNotEmpty == true,
                        onOpenBackup: () => context.push('/settings/backup'),
                        onOpenSignature: () =>
                            context.push('/settings/signature'),
                        onOpenTemplates: () =>
                            context.push('/settings/templates'),
                        onOpenSeal: () => context.push('/settings/seal'),
                        onOpenAi: () => context.push('/settings/ai'),
                      ),
                      const SizedBox(height: 16),
                      const SettingsSectionTitle(
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
                              subtitle:
                                  settings['teacher_name'] ??
                                  kDefaultTeacherName,
                              trailing: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                              ),
                              onTap: () => _editTeacherName(
                                settings['teacher_name'] ?? kDefaultTeacherName,
                              ),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _SettingsTile(
                              icon: Icons.business_outlined,
                              title: '机构名称',
                              subtitle: institutionName,
                              trailing: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                              ),
                              onTap: () =>
                                  _editInstitutionName(institutionName),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SettingsSectionTitle(
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
                              subtitle: isOverdue
                                  ? '建议立即执行一次本地备份'
                                  : '查看最近备份并导出备份文件',
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
                              subtitle:
                                  settings['seal_text'] ?? kDefaultSealText,
                              onTap: () => context.push('/settings/seal'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SettingsSectionTitle(
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
                                ref
                                    .read(settingsProvider.notifier)
                                    .set(
                                      'default_watermark_enabled',
                                      value.toString(),
                                    );
                                unawaited(
                                  InteractionFeedback.selection(context),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _SettingsTile(
                              icon: Icons.message_outlined,
                              title: '默认寄语',
                              subtitle:
                                  settings['default_message_template']
                                          ?.isNotEmpty ==
                                      true
                                  ? settings['default_message_template']!
                                  : '尚未设置默认寄语',
                              trailing: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                              ),
                              onTap: () => _editMessage(
                                settings['default_message_template'] ?? '',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SettingsSectionTitle(title: '提醒策略'),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.notifications_active_outlined,
                              title: '恢复已忽略提醒',
                              subtitle: '清空已忽略的经营提醒，欠费、续费、流失和进步提醒会重新计算。',
                              onTap: _restoreDismissedInsights,
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            const _SettingsInfoTile(
                              icon: Icons.info_outline,
                              title: '提醒恢复规则',
                              subtitle:
                                  '欠费/续费默认 3 天后恢复，流失/试听/高峰 7 天后恢复，进步提醒 14 天后恢复。',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SettingsSectionTitle(
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
                                ref
                                    .read(settingsProvider.notifier)
                                    .set(
                                      InteractionFeedback.hapticsEnabledKey,
                                      value.toString(),
                                    );
                                if (value) {
                                  unawaited(
                                    InteractionFeedback.selection(context),
                                  );
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
                                ref
                                    .read(settingsProvider.notifier)
                                    .set(
                                      InteractionFeedback.soundEnabledKey,
                                      value.toString(),
                                    );
                                unawaited(
                                  InteractionFeedback.selection(context),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SettingsSectionTitle(
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
                              subtitle:
                                  settings['qwen_model']?.trim().isNotEmpty ==
                                      true
                                  ? settings['qwen_model']!
                                  : '计划调用 Qwen3-VL-Plus',
                              onTap: () => context.push('/settings/ai'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SettingsSectionTitle(
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
                      if (kDebugMode && _devMode) ...[
                        const SizedBox(height: 20),
                        SettingsSectionTitle(
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
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
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
                      SettingsSectionTitle(
                        title: '关于应用',
                        subtitle: kDebugMode
                            ? '查看版本信息，并保留隐藏的开发者模式入口。'
                            : '查看版本信息。',
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.info_outline,
                              title: '墨韵',
                              subtitle: !kDebugMode
                                  ? '版本 $versionStr'
                                  : _devMode
                                  ? '版本 $versionStr · 开发者模式已开启'
                                  : '版本 $versionStr · 连续点击 5 次可开启开发者模式',
                              onTap: () {
                                if (!kDebugMode || _devMode) return;
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
      floatingActionButton: reduceMotion
          ? Opacity(opacity: _showScrollToTop ? 1 : 0, child: scrollToTopAction)
          : AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: _showScrollToTop ? Offset.zero : const Offset(0, 1.6),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showScrollToTop ? 1 : 0,
                child: scrollToTopAction,
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
      onSave: (value) =>
          ref.read(settingsProvider.notifier).set('teacher_name', value),
    );
  }

  void _editInstitutionName(String current) {
    _showTextEditSheet(
      title: '机构名称',
      hintText: '请输入机构名称',
      initialValue: current,
      maxLines: 1,
      allowEmpty: false,
      onSave: (value) =>
          ref.read(settingsProvider.notifier).set('institution_name', value),
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
      onSave: (value) => ref
          .read(settingsProvider.notifier)
          .set('default_message_template', value),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _TextEditSheet(
        title: title,
        hintText: hintText,
        initialValue: initialValue,
        maxLines: maxLines,
        maxLength: maxLength,
        allowEmpty: allowEmpty,
        onSave: onSave,
      ),
    );
  }

  Future<void> _restoreDismissedInsights() async {
    final confirmed = await AppToast.showConfirm(
      context,
      '将恢复所有已忽略的经营提醒，确定继续吗？',
    );
    if (!confirmed) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('dismissed_insights');
      invalidateStatistics(ref);
      if (!mounted) return;
      await InteractionFeedback.seal(context);
      if (!mounted) return;
      AppToast.showSuccess(context, '已恢复所有经营提醒');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    }
  }

  Future<void> _seedTestData() async {
    if (!kDebugMode) return;
    final confirmed = await AppToast.showConfirm(
      context,
      '将插入 20 名学生和约 5000 条出勤记录，确定继续吗？',
    );
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
    if (!kDebugMode) return;
    final confirmed = await AppToast.showConfirm(
      context,
      '将删除所有本地数据且不可恢复，确定继续吗？',
    );
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
      await const AttendanceArtworkStorageService().clearArtworkDirectory();
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
        description: '请先生成最新备份。',
        actionLabel: '前往备份',
        action: _PriorityAction.backup,
        color: kOrange,
      );
    }
    if (!hasSignature) {
      return const _PrioritySuggestion(
        title: '建议补充教师签名',
        description: '上传后即可用于导出。',
        actionLabel: '上传签名',
        action: _PriorityAction.signature,
        color: kSealRed,
      );
    }
    if (!hasDefaultMessage) {
      return const _PrioritySuggestion(
        title: '可以补充默认寄语',
        description: '设置后可直接复用。',
        actionLabel: '编辑寄语',
        action: _PriorityAction.message,
        color: kPrimaryBlue,
      );
    }
    if (!hasCustomTeacherName) {
      return const _PrioritySuggestion(
        title: '建议更新教师抬头',
        description: '使用真实姓名更统一。',
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
        _editMessage(
          ref.read(settingsProvider).valueOrNull?['default_message_template'] ??
              '',
        );
        break;
      case _PriorityAction.teacher:
        _editTeacherName(
          ref.read(settingsProvider).valueOrNull?['teacher_name'] ??
              kDefaultTeacherName,
        );
        break;
    }
  }
}

class _TextEditSheet extends StatefulWidget {
  const _TextEditSheet({
    required this.title,
    required this.hintText,
    required this.initialValue,
    required this.onSave,
    required this.maxLines,
    required this.allowEmpty,
    this.maxLength,
  });

  final String title;
  final String hintText;
  final String initialValue;
  final Future<void> Function(String value) onSave;
  final int maxLines;
  final int? maxLength;
  final bool allowEmpty;

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving) return;

    final value = _ctrl.text.trim();
    if (!widget.allowEmpty && value.isEmpty) {
      AppToast.showError(context, '${widget.title}不能为空');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showError(context, '保存失败：$error');
      return;
    }

    if (!mounted) return;
    await InteractionFeedback.seal(context);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.zero,
        child: GlassCard(
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                16,
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
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ctrl,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.title,
                  hintText: widget.hintText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.56),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _saving ? null : _handleSave,
                child: _saving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('保存中...'),
                        ],
                      )
                    : const Text('保存修改'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PriorityAction { backup, signature, message, teacher }

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
          final contentWidth = compact
              ? constraints.maxWidth
              : constraints.maxWidth - buttonWidth - 14;

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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
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

class _SettingsInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kInkSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: kInkSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
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
        onTap: () {
          unawaited(InteractionFeedback.selection(context));
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: resolvedIconColor.withValues(alpha: 0.1),
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
              trailing ??
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: kInkSecondary,
                  ),
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
    final switchControl = IgnorePointer(
      child: Switch(
        value: value,
        activeThumbColor: kPrimaryBlue,
        onChanged: onChanged,
      ),
    );

    final content = Row(
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
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );

    void toggle() => onChanged(!value);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Semantics(
          container: true,
          button: true,
          toggled: value,
          label: title,
          value: value ? '已开启' : '已关闭',
          hint: value ? '轻触关闭。$subtitle' : '轻触开启。$subtitle',
          onTap: toggle,
          child: ExcludeSemantics(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            content,
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: switchControl,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: content),
                            const SizedBox(width: 12),
                            switchControl,
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
