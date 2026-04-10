import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsOverviewPanel extends StatelessWidget {
  final String version;
  final String teacherName;
  final String backupSummary;
  final bool isBackupOverdue;
  final bool watermarkEnabled;
  final bool hasDefaultMessage;
  final int setupReadyCount;
  final double setupCompletion;
  final String priorityHint;
  final bool hasSignature;
  final bool hasSeal;
  final bool hasAiConfig;
  final VoidCallback onOpenBackup;
  final VoidCallback onOpenSignature;
  final VoidCallback onOpenTemplates;
  final VoidCallback onOpenSeal;
  final VoidCallback onOpenAi;

  const SettingsOverviewPanel({
    super.key,
    required this.version,
    required this.teacherName,
    required this.backupSummary,
    required this.isBackupOverdue,
    required this.watermarkEnabled,
    required this.hasDefaultMessage,
    required this.setupReadyCount,
    required this.setupCompletion,
    required this.priorityHint,
    required this.hasSignature,
    required this.hasSeal,
    required this.hasAiConfig,
    required this.onOpenBackup,
    required this.onOpenSignature,
    required this.onOpenTemplates,
    required this.onOpenSeal,
    required this.onOpenAi,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
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
                width: version.isEmpty ? 220 : 160,
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
              if (version.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: kInkSecondary.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    'v$version',
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
              final itemWidth =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: SettingsSnapshot(
                      icon: Icons.person_outline,
                      label: '教师抬头',
                      value: teacherName,
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsSnapshot(
                      icon: Icons.backup_outlined,
                      label: '最近备份',
                      value: backupSummary,
                      color: isBackupOverdue ? kOrange : kGreen,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsSnapshot(
                      icon: Icons.water_drop_outlined,
                      label: 'PDF 水印',
                      value: watermarkEnabled ? '已开启' : '已关闭',
                      color: watermarkEnabled ? kPrimaryBlue : kInkSecondary,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsSnapshot(
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kInkSecondary.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '配置完成度',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$setupReadyCount/4 项已就绪',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kPrimaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: setupCompletion,
                    backgroundColor: kInkSecondary.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  priorityHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SettingsSectionTitle(
            title: '常用入口',
            subtitle: '把最常打开的设置集中放在顶部，减少来回查找。',
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 4 : 2;
              final itemWidth =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.backup_outlined,
                      title: '数据备份',
                      subtitle: isBackupOverdue ? '建议更新' : '查看记录',
                      color: isBackupOverdue ? kOrange : kPrimaryBlue,
                      onTap: onOpenBackup,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.draw_outlined,
                      title: '签名管理',
                      subtitle: hasSignature ? '已配置' : '待上传',
                      color: hasSignature ? kGreen : kSealRed,
                      onTap: onOpenSignature,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.view_quilt_outlined,
                      title: '课堂模板',
                      subtitle: '时段与课程',
                      color: kPrimaryBlue,
                      onTap: onOpenTemplates,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.approval_outlined,
                      title: '印章样式',
                      subtitle: hasSeal ? '已设置' : '待配置',
                      color: kSealRed,
                      onTap: onOpenSeal,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.psychology_alt_outlined,
                      title: 'AI 视觉',
                      subtitle: hasAiConfig ? 'Qwen 已配置' : '待接入',
                      color: hasAiConfig ? kGreen : kPrimaryBlue,
                      onTap: onOpenAi,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class SettingsSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SettingsSectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class SettingsSnapshot extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const SettingsSnapshot({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: kInkSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const SettingsShortcutCard({
    super.key,
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
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 12),
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
      ),
    );
  }
}
