import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restart_app/restart_app.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/backup_helper.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('数据备份与恢复')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (settings) {
          final lastBackupMs = int.tryParse(settings['last_backup_at'] ?? '');
          final lastBackup =
              lastBackupMs != null ? DateTime.fromMillisecondsSinceEpoch(lastBackupMs) : null;
          final isOverdue =
              lastBackup == null || DateTime.now().difference(lastBackup).inDays >= kBackupWarningDays;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isOverdue)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: kOrange.withValues(alpha: 0.12),
                    border: Border.all(color: kOrange.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lastBackup == null
                        ? '尚未备份，建议立即备份。'
                        : '距离上次备份已超过 $kBackupWarningDays 天，建议立即备份。',
                    style: const TextStyle(color: kOrange),
                  ),
                ),
              if (lastBackup != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '上次备份：${formatDate(lastBackup)} '
                    '${lastBackup.hour.toString().padLeft(2, '0')}:${lastBackup.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ElevatedButton.icon(
                icon: const Icon(Icons.backup),
                label: const Text('立即备份'),
                onPressed: () async {
                  try {
                    await BackupHelper.backup();
                    await ref
                        .read(settingsProvider.notifier)
                        .set('last_backup_at', DateTime.now().millisecondsSinceEpoch.toString());
                    if (context.mounted) {
                      AppToast.showSuccess(context, '备份成功，已保存到下载目录');
                    }
                  } catch (e) {
                    if (context.mounted) AppToast.showError(context, e.toString());
                  }
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text('从文件恢复'),
                onPressed: () async {
                  final confirm = await AppToast.showConfirm(
                    context,
                    '恢复将覆盖当前所有数据，此操作不可撤销。确认继续吗？',
                  );
                  if (!confirm) return;
                  try {
                    final restored = await BackupHelper.restore();
                    if (restored) {
                      Restart.restartApp();
                    }
                  } catch (e) {
                    if (context.mounted) AppToast.showError(context, e.toString());
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
