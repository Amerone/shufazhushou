import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import 'settings_overview_panel.dart';
import 'settings_screen_tiles.dart';

class SettingsTeacherProfileSection extends StatelessWidget {
  final String teacherName;
  final String institutionName;
  final VoidCallback onEditTeacherName;
  final VoidCallback onEditInstitutionName;

  const SettingsTeacherProfileSection({
    super.key,
    required this.teacherName,
    required this.institutionName,
    required this.onEditTeacherName,
    required this.onEditInstitutionName,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionBlock(
      title: '教师资料',
      subtitle: '首页与报告抬头。',
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SettingsTile(
              icon: Icons.person_outline,
              title: '教师姓名',
              subtitle: teacherName,
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: onEditTeacherName,
            ),
            _tileDivider,
            SettingsTile(
              icon: Icons.business_outlined,
              title: '机构名称',
              subtitle: institutionName,
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: onEditInstitutionName,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsAssetsTemplatesSection extends StatelessWidget {
  final String backupSubtitle;
  final bool backupWarning;
  final String sealText;
  final VoidCallback onOpenBackup;
  final VoidCallback onOpenTemplates;
  final VoidCallback onOpenSignature;
  final VoidCallback onOpenSeal;

  const SettingsAssetsTemplatesSection({
    super.key,
    required this.backupSubtitle,
    required this.backupWarning,
    required this.sealText,
    required this.onOpenBackup,
    required this.onOpenTemplates,
    required this.onOpenSignature,
    required this.onOpenSeal,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionBlock(
      title: '资料与模板',
      subtitle: '备份、模板、签名、印章。',
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SettingsTile(
              icon: Icons.backup_outlined,
              title: '数据备份',
              subtitle: backupSubtitle,
              warning: backupWarning,
              onTap: onOpenBackup,
            ),
            _tileDivider,
            SettingsTile(
              icon: Icons.view_quilt_outlined,
              title: '课堂模板',
              subtitle: '常用时段',
              onTap: onOpenTemplates,
            ),
            _tileDivider,
            SettingsTile(
              icon: Icons.draw_outlined,
              title: '签名管理',
              subtitle: '报告签名',
              onTap: onOpenSignature,
            ),
            _tileDivider,
            SettingsTile(
              icon: Icons.approval_outlined,
              title: '印章样式',
              subtitle: sealText,
              onTap: onOpenSeal,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsExportCommunicationSection extends StatelessWidget {
  final bool watermarkEnabled;
  final ValueChanged<bool> onWatermarkChanged;
  final String defaultMessageSubtitle;
  final VoidCallback onEditMessage;

  const SettingsExportCommunicationSection({
    super.key,
    required this.watermarkEnabled,
    required this.onWatermarkChanged,
    required this.defaultMessageSubtitle,
    required this.onEditMessage,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionBlock(
      title: '导出与沟通',
      subtitle: '报告默认项。',
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SettingsSwitchTile(
              value: watermarkEnabled,
              icon: Icons.water_drop_outlined,
              title: '默认启用 PDF 水印',
              subtitle: '自动附加标识',
              onChanged: onWatermarkChanged,
            ),
            _tileDivider,
            SettingsTile(
              icon: Icons.message_outlined,
              title: '默认寄语',
              subtitle: defaultMessageSubtitle,
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: onEditMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsReminderStrategySection extends StatelessWidget {
  final VoidCallback onRestoreDismissedInsights;

  const SettingsReminderStrategySection({
    super.key,
    required this.onRestoreDismissedInsights,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionBlock(
      title: '提醒策略',
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SettingsTile(
              icon: Icons.notifications_active_outlined,
              title: '恢复已忽略提醒',
              subtitle: '重新计算已忽略提醒。',
              onTap: onRestoreDismissedInsights,
            ),
            _tileDivider,
            const SettingsInfoTile(
              icon: Icons.info_outline,
              title: '恢复规则',
              subtitle: '欠费/续费 3 天，流失/试听/高峰 7 天，进步 14 天。',
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsImmersiveFeedbackSection extends StatelessWidget {
  final bool hapticsEnabled;
  final ValueChanged<bool> onHapticsChanged;
  final bool soundEnabled;
  final ValueChanged<bool> onSoundChanged;

  const SettingsImmersiveFeedbackSection({
    super.key,
    required this.hapticsEnabled,
    required this.onHapticsChanged,
    required this.soundEnabled,
    required this.onSoundChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionBlock(
      title: '沉浸反馈',
      subtitle: '保存与切换反馈。',
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SettingsSwitchTile(
              value: hapticsEnabled,
              icon: Icons.vibration_outlined,
              title: '启用触感反馈',
              subtitle: '关键操作轻震',
              onChanged: onHapticsChanged,
            ),
            _tileDivider,
            SettingsSwitchTile(
              value: soundEnabled,
              icon: Icons.music_note_outlined,
              title: '启用轻音反馈',
              subtitle: '导出完成提示音',
              onChanged: onSoundChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsAiExtensionSection extends StatelessWidget {
  final String modelSubtitle;
  final VoidCallback onOpenAi;

  const SettingsAiExtensionSection({
    super.key,
    required this.modelSubtitle,
    required this.onOpenAi,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionBlock(
      title: 'AI 扩展',
      subtitle: '模型与远端配置。',
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SettingsTile(
              icon: Icons.psychology_alt_outlined,
              title: 'Qwen 视觉模型',
              subtitle: modelSubtitle,
              onTap: onOpenAi,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsImportToolsSection extends StatelessWidget {
  final VoidCallback onDownloadTemplate;

  const SettingsImportToolsSection({
    super.key,
    required this.onDownloadTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionBlock(
      title: '导入工具',
      subtitle: '学生名单模板。',
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SettingsTile(
              icon: Icons.download_outlined,
              title: '下载学生导入模板',
              subtitle: '生成 Excel 模板',
              onTap: onDownloadTemplate,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsDeveloperToolsSection extends StatelessWidget {
  final VoidCallback onSeedTestData;
  final VoidCallback onClearAllData;

  const SettingsDeveloperToolsSection({
    super.key,
    required this.onSeedTestData,
    required this.onClearAllData,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionBlock(
      title: '开发者工具',
      subtitle: '本地演示与压测。',
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SettingsTile(
              icon: Icons.science_outlined,
              title: '生成测试数据',
              subtitle: '20 名学生和出勤记录',
              onTap: onSeedTestData,
            ),
            _tileDivider,
            SettingsTile(
              icon: Icons.delete_forever_outlined,
              title: '清空全部数据',
              subtitle: '删除所有本地记录。',
              titleColor: kRed,
              iconColor: kRed,
              onTap: onClearAllData,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsAboutSection extends StatelessWidget {
  final String sectionSubtitle;
  final String versionSubtitle;
  final VoidCallback onVersionTap;

  const SettingsAboutSection({
    super.key,
    required this.sectionSubtitle,
    required this.versionSubtitle,
    required this.onVersionTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionBlock(
      title: '关于应用',
      subtitle: sectionSubtitle,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SettingsTile(
              icon: Icons.info_outline,
              title: '墨韵',
              subtitle: versionSubtitle,
              onTap: onVersionTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionBlock extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SettingsSectionBlock({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

const _tileDivider = Divider(height: 1, indent: 16, endIndent: 16);
