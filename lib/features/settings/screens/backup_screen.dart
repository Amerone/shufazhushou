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
              onBack: () => context.pop(),
            ),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (settings) {
                  final lastBackupMs = int.tryParse(settings['last_backup_at'] ?? '');
                  final lastBackup = lastBackupMs != null
                      ? DateTime.fromMillisecondsSinceEpoch(lastBackupMs)
                      : null;
                  final isOverdue = lastBackup == null ||
                      DateTime.now().difference(lastBackup).inDays >=
                          kBackupWarningDays;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      if (isOverdue)
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kOrange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning_amber_rounded, color: kOrange),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  lastBackup == null
                                      ? '尚未备份，建议立即生成一份备份。'
                                      : '距离上次备份已超过 $kBackupWarningDays 天，建议立即备份。',
                                  style: const TextStyle(color: kOrange, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '备份详情',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (lastBackup != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.history, size: 18, color: kInkSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    '上次备份：${formatDate(lastBackup)} '
                                    '${lastBackup.hour.toString().padLeft(2, '0')}:'
                                    '${lastBackup.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: kInkSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 18, color: kInkSecondary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '备份会先生成到应用私有目录，再通过系统分享面板导出，不再依赖共享存储权限。',
                                    style: TextStyle(color: kInkSecondary, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.backup_outlined),
                                label: const Text('立即备份'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  try {
                                    final path = await BackupHelper.backup();
                                    await ref.read(settingsProvider.notifier).set(
                                          'last_backup_at',
                                          DateTime.now().millisecondsSinceEpoch.toString(),
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
                                        '备份文件已生成，请在系统分享面板中保存',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppToast.showError(context, e.toString());
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.restore),
                                label: const Text('从文件恢复'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  final confirm = await AppToast.showConfirm(
                                    context,
                                    '恢复会覆盖当前所有数据，此操作不可撤销。确认继续吗？',
                                  );
                                  if (!confirm) return;
                                  try {
                                    final restored = await BackupHelper.restore();
                                    if (restored) {
                                      Restart.restartApp();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppToast.showError(context, e.toString());
                                    }
                                  }
                                },
                              ),
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