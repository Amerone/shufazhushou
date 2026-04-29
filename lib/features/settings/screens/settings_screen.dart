import 'dart:async';
import 'dart:io';

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
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/settings_overview_panel.dart';
import '../widgets/settings_screen_sections.dart';
import '../widgets/settings_screen_tiles.dart';
import '../widgets/settings_text_edit_sheet.dart';

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
                  final priorityHint = priority == null
                      ? '当前导出与备份配置已经比较完整，可以继续微调细节。'
                      : '下一步建议先处理“${priority.actionLabel}”，这样后续导出和沟通会更顺手。';
                  final backupTileSubtitle = isOverdue
                      ? '建议立即执行一次本地备份'
                      : '查看最近备份并导出备份文件';
                  final messageSubtitle =
                      settings['default_message_template']?.isNotEmpty == true
                      ? settings['default_message_template']!
                      : '尚未设置默认寄语';
                  final qwenModelSubtitle =
                      settings['qwen_model']?.trim().isNotEmpty == true
                      ? settings['qwen_model']!
                      : '计划调用 Qwen3-VL-Plus';
                  const aboutSectionSubtitle = kDebugMode
                      ? '查看版本信息，并保留隐藏的开发者模式入口。'
                      : '查看版本信息。';
                  final aboutVersionSubtitle = !kDebugMode
                      ? '版本 $versionStr'
                      : _devMode
                      ? '版本 $versionStr · 开发者模式已开启'
                      : '版本 $versionStr · 连续点击 5 次可开启开发者模式';

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
                        SettingsPriorityBanner(
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
                        priorityHint: priorityHint,
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
                      SettingsTeacherProfileSection(
                        teacherName: teacherName,
                        institutionName: institutionName,
                        onEditTeacherName: () => _editTeacherName(teacherName),
                        onEditInstitutionName: () =>
                            _editInstitutionName(institutionName),
                      ),
                      const SizedBox(height: 20),
                      SettingsAssetsTemplatesSection(
                        backupSubtitle: backupTileSubtitle,
                        backupWarning: isOverdue,
                        sealText: settings['seal_text'] ?? kDefaultSealText,
                        onOpenBackup: () => context.push('/settings/backup'),
                        onOpenTemplates: () =>
                            context.push('/settings/templates'),
                        onOpenSignature: () =>
                            context.push('/settings/signature'),
                        onOpenSeal: () => context.push('/settings/seal'),
                      ),
                      const SizedBox(height: 20),
                      SettingsExportCommunicationSection(
                        watermarkEnabled: watermarkEnabled,
                        onWatermarkChanged: (value) {
                          ref
                              .read(settingsProvider.notifier)
                              .set(
                                'default_watermark_enabled',
                                value.toString(),
                              );
                          unawaited(InteractionFeedback.selection(context));
                        },
                        defaultMessageSubtitle: messageSubtitle,
                        onEditMessage: () => _editMessage(
                          settings['default_message_template'] ?? '',
                        ),
                      ),
                      const SizedBox(height: 20),
                      SettingsReminderStrategySection(
                        onRestoreDismissedInsights: _restoreDismissedInsights,
                      ),
                      const SizedBox(height: 20),
                      SettingsImmersiveFeedbackSection(
                        hapticsEnabled: hapticsEnabled,
                        onHapticsChanged: (value) {
                          ref
                              .read(settingsProvider.notifier)
                              .set(
                                InteractionFeedback.hapticsEnabledKey,
                                value.toString(),
                              );
                          if (value) {
                            unawaited(InteractionFeedback.selection(context));
                          }
                        },
                        soundEnabled: soundEnabled,
                        onSoundChanged: (value) {
                          ref
                              .read(settingsProvider.notifier)
                              .set(
                                InteractionFeedback.soundEnabledKey,
                                value.toString(),
                              );
                          unawaited(InteractionFeedback.selection(context));
                        },
                      ),
                      const SizedBox(height: 20),
                      SettingsAiExtensionSection(
                        modelSubtitle: qwenModelSubtitle,
                        onOpenAi: () => context.push('/settings/ai'),
                      ),
                      const SizedBox(height: 20),
                      SettingsImportToolsSection(
                        onDownloadTemplate: _downloadTemplate,
                      ),
                      if (kDebugMode && _devMode) ...[
                        const SizedBox(height: 20),
                        SettingsDeveloperToolsSection(
                          onSeedTestData: _seedTestData,
                          onClearAllData: _clearAllData,
                        ),
                      ],
                      const SizedBox(height: 20),
                      SettingsAboutSection(
                        sectionSubtitle: aboutSectionSubtitle,
                        versionSubtitle: aboutVersionSubtitle,
                        onVersionTap: () {
                          if (!kDebugMode || _devMode) return;
                          _versionTapCount++;
                          if (_versionTapCount >= 5) {
                            setState(() => _devMode = true);
                            AppToast.showSuccess(context, '已进入开发者模式');
                          }
                        },
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
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SettingsTextEditSheet(
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
