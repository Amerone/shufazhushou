import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 380;
              final textWidth = compact
                  ? constraints.maxWidth
                  : constraints.maxWidth - (version.isEmpty ? 60 : 150);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.tune_outlined, color: kPrimaryBlue),
                  ),
                  SizedBox(
                    width: textWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '配置状态',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '先处理影响导出和备份的项。',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  if (version.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
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
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _overviewColumnCount(constraints.maxWidth);
              final itemWidth =
                  (constraints.maxWidth - 10 * (columns - 1)) / columns;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(14),
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
                      '$setupReadyCount/4',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kPrimaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: setupCompletion,
                    backgroundColor: kInkSecondary.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  priorityHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SettingsSectionTitle(title: '常用入口', subtitle: '高频设置。'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _overviewColumnCount(constraints.maxWidth);
              final itemWidth =
                  (constraints.maxWidth - 10 * (columns - 1)) / columns;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.backup_outlined,
                      title: '备份',
                      subtitle: isBackupOverdue ? '建议更新' : '查看记录',
                      color: isBackupOverdue ? kOrange : kPrimaryBlue,
                      onTap: onOpenBackup,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.draw_outlined,
                      title: '签名',
                      subtitle: hasSignature ? '已配置' : '待上传',
                      color: hasSignature ? kGreen : kSealRed,
                      onTap: onOpenSignature,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.view_quilt_outlined,
                      title: '模板',
                      subtitle: '时段',
                      color: kPrimaryBlue,
                      onTap: onOpenTemplates,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.approval_outlined,
                      title: '印章',
                      subtitle: hasSeal ? '已设置' : '待配置',
                      color: kSealRed,
                      onTap: onOpenSeal,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SettingsShortcutCard(
                      icon: Icons.psychology_alt_outlined,
                      title: 'AI',
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

int _overviewColumnCount(double maxWidth) {
  if (maxWidth >= 720) return 4;
  if (maxWidth >= 320) return 2;
  return 1;
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: kInkSecondary),
          ),
          const SizedBox(height: 4),
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
        borderRadius: BorderRadius.circular(16),
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          unawaited(InteractionFeedback.selection(context));
          onTap();
        },
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
