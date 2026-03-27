import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restart_app/restart_app.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/backup_helper.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  String _lastBackupLabel(DateTime? lastBackup) {
    if (lastBackup == null) return '未创建';
    final days = DateTime.now().difference(lastBackup).inDays;
    if (days <= 0) return '今天';
    return '$days 天前';
  }

  String _lastBackupTime(DateTime? lastBackup) {
    if (lastBackup == null) return '暂无备份记录';
    return '${formatDate(lastBackup)} '
        '${lastBackup.hour.toString().padLeft(2, '0')}:'
        '${lastBackup.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '数据备份与恢复',
              subtitle: '建议定期生成本地备份，避免设备异常导致记录丢失。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (settings) {
                  final lastBackupMs = int.tryParse(settings['last_backup_at'] ?? '');
                  final lastBackup = lastBackupMs == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch(lastBackupMs);
                  final isOverdue = lastBackup == null ||
                      DateTime.now().difference(lastBackup).inDays >=
                          kBackupWarningDays;
                  final statusColor = isOverdue ? kOrange : kGreen;

                  return ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                    children: [
                      if (isOverdue)
                        GlassCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: kOrange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: kOrange,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  lastBackup == null
                                      ? '尚未创建过备份，建议立即生成第一份本地备份。'
                                      : '距离上次备份已超过 $kBackupWarningDays 天，建议现在更新备份。',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: kOrange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      GlassCard(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
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
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.storage_outlined,
                                    color: statusColor,
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '备份摘要',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isOverdue
                                            ? '建议先执行一次本地备份，再继续进行大范围数据调整。'
                                            : '当前备份状态较稳，可按周期继续维护本地副本。',
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isOverdue ? '建议更新' : '状态正常',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns =
                                    constraints.maxWidth >= 720 ? 4 : 2;
                                final itemWidth =
                                    (constraints.maxWidth -
                                            12 * (columns - 1)) /
                                        columns;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: itemWidth,
                                      child: _BackupMetric(
                                        label: '最近一次',
                                        value: _lastBackupLabel(lastBackup),
                                        color: statusColor,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _BackupMetric(
                                        label: '上次时间',
                                        value: lastBackup == null
                                            ? '暂无记录'
                                            : formatDate(lastBackup),
                                        color: kPrimaryBlue,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _BackupMetric(
                                        label: '建议周期',
                                        value: '$kBackupWarningDays 天',
                                        color: kSealRed,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: const _BackupMetric(
                                        label: '恢复方式',
                                        value: '整库覆盖',
                                        color: kPrimaryBlue,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _BackupMetaBadge(
                                  icon: Icons.key_off_outlined,
                                  label: 'AI API Key 不含在备份内',
                                  color: kOrange,
                                ),
                                _BackupMetaBadge(
                                  icon: Icons.share_outlined,
                                  label: '通过系统分享面板导出',
                                  color: kPrimaryBlue,
                                ),
                                _BackupMetaBadge(
                                  icon: Icons.restart_alt_outlined,
                                  label: '恢复成功后自动重启',
                                  color: kSealRed,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BackupSectionHeader(
                              title: '执行说明',
                              subtitle:
                                  '这一轮操作会如何保存、恢复后会发生什么，都可以先在这里确认。',
                              trailing: isOverdue ? '先备份' : '流程清晰',
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 460;
                                final columns = constraints.maxWidth >= 720
                                    ? 3
                                    : (compact ? 1 : 2);
                                final itemWidth =
                                    (constraints.maxWidth -
                                            12 * (columns - 1)) /
                                        columns;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: itemWidth,
                                      child: const _BackupStepCard(
                                        icon: Icons.backup_outlined,
                                        title: '生成副本',
                                        description:
                                            '点击立即备份后，应用会先在本地生成当前数据库副本。',
                                        color: kGreen,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: const _BackupStepCard(
                                        icon: Icons.share_outlined,
                                        title: '保存到外部',
                                        description:
                                            '随后会打开系统分享面板，你可以发到云盘、聊天或文件管理。',
                                        color: kPrimaryBlue,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: const _BackupStepCard(
                                        icon: Icons.restart_alt_outlined,
                                        title: '恢复并重启',
                                        description:
                                            '恢复会用备份文件覆盖当前数据，成功后应用会自动重启。',
                                        color: kSealRed,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            _InfoRow(
                              icon: Icons.history,
                              text: '当前记录：${_lastBackupTime(lastBackup)}',
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              icon: isOverdue
                                  ? Icons.priority_high_rounded
                                  : Icons.verified_outlined,
                              text: isOverdue
                                  ? '建议先创建一份新的兜底备份，再进行恢复或批量调整数据。'
                                  : '当前已有近期备份，继续导出资料或调整模板会更从容。',
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 460;
                                final buttonWidth = compact
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 12) / 2;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: buttonWidth,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        onPressed: () async {
                                          try {
                                            final path =
                                                await BackupHelper.backup();
                                            await ref
                                                .read(
                                                  settingsProvider.notifier,
                                                )
                                                .set(
                                                  'last_backup_at',
                                                  DateTime.now()
                                                      .millisecondsSinceEpoch
                                                      .toString(),
                                                );
                                            if (context.mounted) {
                                              await SharePlus.instance.share(
                                                ShareParams(
                                                  files: [XFile(path)],
                                                  text: '书法助手数据备份',
                                                ),
                                              );
                                            }
                                            if (context.mounted) {
                                              AppToast.showSuccess(
                                                context,
                                                '备份文件已生成，请在系统分享面板中保存。',
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              AppToast.showError(
                                                context,
                                                e.toString(),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.backup_outlined,
                                        ),
                                        label: const Text('立即备份'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: buttonWidth,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        onPressed: () async {
                                          final confirm =
                                              await AppToast.showConfirm(
                                            context,
                                            '恢复会覆盖当前所有数据，且无法撤销。确认继续吗？',
                                          );
                                          if (!confirm) return;

                                          try {
                                            final restored =
                                                await BackupHelper.restore();
                                            if (restored) {
                                              Restart.restartApp();
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              AppToast.showError(
                                                context,
                                                e.toString(),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.restore),
                                        label: const Text('从文件恢复'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: kRed.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const _InfoRow(
                                icon: Icons.warning_amber_rounded,
                                text:
                                    '恢复成功后应用会自动重启，请确保当前数据已经完成备份再执行恢复。',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const GlassCard(
                        padding: EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BackupSectionHeader(
                              title: '风险提示',
                              subtitle:
                                  '把备份文件放到应用外部，并在恢复前保留当前版本，能明显降低误操作风险。',
                            ),
                            SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.folder_zip_outlined,
                              text:
                                  '建议将备份文件同步到云盘或发送到另一台设备，避免单机损坏导致无法恢复。',
                            ),
                            SizedBox(height: 10),
                            _InfoRow(
                              icon: Icons.verified_user_outlined,
                              text: '恢复前可先执行一次当前环境备份，作为兜底版本保留。',
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
}

class _BackupSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;

  const _BackupSectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: trailing == null || compact
                  ? constraints.maxWidth
                  : constraints.maxWidth - 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: kInkSecondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(trailing!, style: theme.textTheme.bodySmall),
              ),
          ],
        );
      },
    );
  }
}

class _BackupMetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BackupMetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: kInkSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _BackupMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BackupMetric({
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
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupStepCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _BackupStepCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
