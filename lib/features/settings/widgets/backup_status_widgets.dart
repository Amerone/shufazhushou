import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import 'backup_common_widgets.dart';

class BackupListErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const BackupListErrorCard({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: kRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '备份列表加载失败，请稍后重试。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: kRed),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class BackupWarningCard extends StatelessWidget {
  final String message;

  const BackupWarningCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: kOrange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackupOverviewCard extends StatelessWidget {
  final Color statusColor;
  final String statusLabel;
  final String lastBackupLabel;
  final String lastBackupTime;
  final int backupCount;
  final String directoryPath;

  const BackupOverviewCard({
    super.key,
    required this.statusColor,
    required this.statusLabel,
    required this.lastBackupLabel,
    required this.lastBackupTime,
    required this.backupCount,
    required this.directoryPath,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.inventory_2_outlined, color: statusColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '备份总览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                  statusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              final columns = constraints.maxWidth >= 720
                  ? 4
                  : constraints.maxWidth >= 420
                  ? 2
                  : 1;
              final itemWidth =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: BackupMetricCard(
                      label: '最近一次',
                      value: lastBackupLabel,
                      color: statusColor,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: BackupMetricCard(
                      label: '上次时间',
                      value: lastBackupTime,
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: BackupMetricCard(
                      label: '应用内备份',
                      value: '$backupCount 份',
                      color: kSealRed,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: const BackupMetricCard(
                      label: '建议周期',
                      value: '7 天',
                      color: kGreen,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kInkSecondary.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '应用内备份位置',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  directoryPath,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
