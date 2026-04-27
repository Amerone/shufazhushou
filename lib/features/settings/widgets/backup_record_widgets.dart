import 'package:flutter/material.dart';

import '../../../core/utils/backup_helper.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import 'backup_common_widgets.dart';

class BackupRecentRecordsSection extends StatelessWidget {
  final ConnectionState connectionState;
  final List<BackupRecord> backups;
  final bool submitting;
  final String Function(BackupRecord record) sizeLabelBuilder;
  final Future<void> Function(BackupRecord record) onShare;
  final Future<void> Function(BackupRecord record) onRestore;

  const BackupRecentRecordsSection({
    super.key,
    required this.connectionState,
    required this.backups,
    required this.submitting,
    required this.sizeLabelBuilder,
    required this.onShare,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BackupSectionHeader(
            title: '最近备份',
            subtitle: '即使你上次没有保存到外部文件，也可以直接在这里重新生成加密分享文件，或恢复应用内副本。',
          ),
          const SizedBox(height: 14),
          if (connectionState == ConnectionState.waiting && backups.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (backups.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.54),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: kInkSecondary.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                '还没有应用内备份，先生成一份。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            )
          else
            ...backups.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BackupRecordCard(
                  record: record,
                  sizeLabel: sizeLabelBuilder(record),
                  onShare: submitting ? null : () => onShare(record),
                  onRestore: submitting ? null : () => onRestore(record),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BackupRestoreAction extends StatelessWidget {
  final BackupRecord record;
  final VoidCallback? onRestore;

  const BackupRestoreAction({super.key, required this.record, this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '恢复备份 ${record.fileName}',
      hint: '会先显示确认提示，确认后覆盖当前全部数据',
      button: true,
      enabled: onRestore != null,
      onTap: onRestore,
      child: ExcludeSemantics(
        child: OutlinedButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.restore_outlined),
          label: const Text('恢复此备份'),
        ),
      ),
    );
  }
}

class BackupRecordCard extends StatelessWidget {
  final BackupRecord record;
  final String sizeLabel;
  final VoidCallback? onShare;
  final VoidCallback? onRestore;

  const BackupRecordCard({
    super.key,
    required this.record,
    required this.sizeLabel,
    required this.onShare,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.fileName,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '${formatDate(record.modifiedAt)} '
            '${record.modifiedAt.hour.toString().padLeft(2, '0')}:'
            '${record.modifiedAt.minute.toString().padLeft(2, '0')}'
            ' · $sizeLabel',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            record.path,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: kInkSecondary, height: 1.45),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined),
                label: const Text('加密分享'),
              ),
              BackupRestoreAction(record: record, onRestore: onRestore),
            ],
          ),
        ],
      ),
    );
  }
}
