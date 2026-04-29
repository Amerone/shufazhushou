import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_card.dart';
import 'backup_common_widgets.dart';

class BackupActionsCard extends StatelessWidget {
  final bool submitting;
  final VoidCallback onCreateBackup;
  final VoidCallback onRestoreFromPicker;

  const BackupActionsCard({
    super.key,
    required this.submitting,
    required this.onCreateBackup,
    required this.onRestoreFromPicker,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BackupSectionHeader(title: '立即操作', subtitle: '生成备份，或从文件恢复。'),
          const SizedBox(height: 14),
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
                      onPressed: submitting ? null : onCreateBackup,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text('生成并分享'),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: OutlinedButton.icon(
                      onPressed: submitting ? null : onRestoreFromPicker,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.restore),
                      label: const Text('从文件恢复'),
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
