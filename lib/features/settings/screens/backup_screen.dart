import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:restart_app/restart_app.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/backup_helper.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  late Future<List<BackupRecord>> _backupsFuture;
  late Future<String> _backupDirectoryFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _refreshBackupState();
  }

  void _refreshBackupState() {
    _backupsFuture = BackupHelper.listBackups();
    _backupDirectoryFuture = BackupHelper.backupDirectoryPath();
  }

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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }

  Future<void> _shareEncryptedFile(String encryptedPath) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(encryptedPath)],
        title: '墨韵加密数据备份',
        text: '这是已加密的墨韵数据备份，恢复时需要输入同一口令。',
      ),
    );
  }

  Future<String?> _promptBackupPassphrase({
    required String title,
    required String description,
    required String actionLabel,
    bool confirmEntry = true,
  }) async {
    final passphraseController = TextEditingController();
    final confirmController = TextEditingController();
    var obscurePassphrase = true;
    var obscureConfirm = true;
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void submit() {
              final passphrase = passphraseController.text;
              final validation = BackupHelper.validatePassphrase(passphrase);
              if (validation != null) {
                setSheetState(() => errorText = validation);
                return;
              }
              if (confirmEntry && passphrase != confirmController.text) {
                setSheetState(() => errorText = '两次输入的备份口令不一致。');
                return;
              }
              Navigator.of(dialogContext).pop(passphrase);
            }

            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kInkSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passphraseController,
                      obscureText: obscurePassphrase,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '备份口令',
                        hintText:
                            '至少 ${BackupHelper.minimumPassphraseLength} 位',
                        errorText: errorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setSheetState(() {
                              obscurePassphrase = !obscurePassphrase;
                            });
                          },
                          icon: Icon(
                            obscurePassphrase
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!confirmEntry) {
                          submit();
                        }
                      },
                    ),
                    if (confirmEntry) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: '再次输入口令',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setSheetState(() {
                                obscureConfirm = !obscureConfirm;
                              });
                            },
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(onPressed: submit, child: Text(actionLabel)),
              ],
            );
          },
        );
      },
    );

    passphraseController.dispose();
    confirmController.dispose();
    return result;
  }

  Future<String?> _resolveRestorePassphrase(String backupPath) {
    if (!BackupHelper.isEncryptedBackupPath(backupPath)) {
      return Future.value(null);
    }

    return _promptBackupPassphrase(
      title: '输入备份口令',
      description: '该备份文件已加密。继续恢复前，请输入创建备份时设置的口令。',
      actionLabel: '继续恢复',
      confirmEntry: false,
    );
  }

  Future<void> _handleCreateBackup() async {
    if (_submitting) return;
    final confirmed = await AppToast.showConfirm(
      context,
      '备份包含学员、家长、课时、收费和课堂作品图片等完整数据。继续后会先生成应用内副本，再导出一个需要口令才能恢复的加密备份文件。确认继续吗？',
    );
    if (!confirmed || !mounted) return;

    final passphrase = await _promptBackupPassphrase(
      title: '设置备份口令',
      description: '分享出去的备份文件会先加密。之后在另一台设备恢复时，需要输入同一口令。',
      actionLabel: '生成并分享',
    );
    if (passphrase == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final issuedAt = DateTime.now();
      final internalPath = await BackupHelper.backup(at: issuedAt);
      final encryptedPath = await BackupHelper.exportEncryptedBackup(
        sourcePath: internalPath,
        passphrase: passphrase,
        at: issuedAt,
      );
      final now = issuedAt.millisecondsSinceEpoch.toString();
      await ref.read(settingsProvider.notifier).setAll({
        'last_backup_at': now,
        'last_backup_path': internalPath,
        'last_backup_name': p.basename(internalPath),
      });
      if (!mounted) return;
      setState(_refreshBackupState);
      await _shareEncryptedFile(encryptedPath);
      if (!mounted) return;
      AppToast.showSuccess(context, '备份已生成，并已按口令加密后打开分享面板。恢复这个文件时需要输入同一口令。');
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleShareBackup(BackupRecord record) async {
    if (!await File(record.path).exists()) {
      if (!mounted) return;
      AppToast.showError(context, '备份文件不存在，请重新生成。');
      setState(_refreshBackupState);
      return;
    }

    final passphrase = await _promptBackupPassphrase(
      title: '设置分享口令',
      description: '这份应用内备份会先转换为加密文件，再通过系统分享面板发送出去。',
      actionLabel: '加密并分享',
    );
    if (passphrase == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final encryptedPath = await BackupHelper.exportEncryptedBackup(
        sourcePath: record.path,
        passphrase: passphrase,
      );
      await _shareEncryptedFile(encryptedPath);
      if (!mounted) return;
      AppToast.showSuccess(context, '已生成加密分享文件。之后恢复这份外部备份时，需要输入同一口令。');
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleRestoreFromPicker() async {
    if (_submitting) return;
    final confirmed = await AppToast.showConfirm(
      context,
      '恢复会覆盖当前全部数据，且无法撤销。建议你先生成一份新的应用内备份，再从外部备份文件恢复。确认继续吗？',
    );
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    try {
      final restorePath = await BackupHelper.pickRestoreSourcePath();
      if (restorePath == null || !mounted) return;
      final passphrase = await _resolveRestorePassphrase(restorePath);
      if (BackupHelper.isEncryptedBackupPath(restorePath) &&
          passphrase == null) {
        return;
      }
      await _createFallbackBackupBeforeRestore();
      await BackupHelper.restoreFromPath(restorePath, passphrase: passphrase);
      await _finalizeSuccessfulRestore();
      if (!mounted) return;
      AppToast.showSuccess(context, '备份已恢复，应用即将重启。');
      Restart.restartApp();
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleRestoreFromRecord(BackupRecord record) async {
    if (_submitting) return;
    final confirmed = await AppToast.showConfirm(
      context,
      '将使用 ${record.fileName} 覆盖当前全部数据，且无法撤销。确认继续恢复吗？',
    );
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      final passphrase = await _resolveRestorePassphrase(record.path);
      if (BackupHelper.isEncryptedBackupPath(record.path) &&
          passphrase == null) {
        return;
      }
      await _createFallbackBackupBeforeRestore();
      await BackupHelper.restoreFromPath(record.path, passphrase: passphrase);
      await _finalizeSuccessfulRestore();
      if (!mounted) return;
      AppToast.showSuccess(context, '备份已恢复，应用即将重启。');
      Restart.restartApp();
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _createBackup() async {
    return _handleCreateBackup();
  }

  Future<void> _shareBackup(BackupRecord record) async {
    return _handleShareBackup(record);
  }

  Future<void> _restoreFromPicker() async {
    return _handleRestoreFromPicker();
  }

  Future<void> _restoreFromRecord(BackupRecord record) async {
    return _handleRestoreFromRecord(record);
  }

  Future<void> _createFallbackBackupBeforeRestore() async {
    final fallbackPath = await BackupHelper.backup();
    await ref.read(settingsProvider.notifier).setAll({
      'last_backup_at': DateTime.now().millisecondsSinceEpoch.toString(),
      'last_backup_path': fallbackPath,
      'last_backup_name': p.basename(fallbackPath),
    });
    if (mounted) {
      setState(_refreshBackupState);
    }
  }

  Future<void> _finalizeSuccessfulRestore() async {
    ref.invalidate(settingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '数据备份与恢复',
              subtitle: '备份后可加密分享，恢复时需口令。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: AsyncValueWidget<Map<String, String>>(
                value: settingsAsync,
                builder: (settings) {
                  final lastBackupMs = int.tryParse(
                    settings['last_backup_at'] ?? '',
                  );
                  final lastBackup = lastBackupMs == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch(lastBackupMs);
                  final isOverdue =
                      lastBackup == null ||
                      DateTime.now().difference(lastBackup).inDays >=
                          kBackupWarningDays;
                  final statusColor = isOverdue ? kOrange : kGreen;

                  return FutureBuilder<List<BackupRecord>>(
                    future: _backupsFuture,
                    builder: (context, snapshot) {
                      final backups = snapshot.data ?? const <BackupRecord>[];

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                        children: [
                          if (isOverdue)
                            GlassCard(
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
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: kOrange,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      lastBackup == null
                                          ? '还没有创建过备份，建议先生成第一份完整副本。'
                                          : '距离上次备份已超过 $kBackupWarningDays 天，建议现在更新一份新的副本。',
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '备份总览',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
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
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                                    final columns = constraints.maxWidth >= 720
                                        ? 4
                                        : 2;
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
                                          child: _MetricCard(
                                            label: '最近一次',
                                            value: _lastBackupLabel(lastBackup),
                                            color: statusColor,
                                          ),
                                        ),
                                        SizedBox(
                                          width: itemWidth,
                                          child: _MetricCard(
                                            label: '上次时间',
                                            value: _lastBackupTime(lastBackup),
                                            color: kPrimaryBlue,
                                          ),
                                        ),
                                        SizedBox(
                                          width: itemWidth,
                                          child: _MetricCard(
                                            label: '应用内备份',
                                            value: '${backups.length} 份',
                                            color: kSealRed,
                                          ),
                                        ),
                                        SizedBox(
                                          width: itemWidth,
                                          child: const _MetricCard(
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
                                FutureBuilder<String>(
                                  future: _backupDirectoryFuture,
                                  builder: (context, directorySnapshot) {
                                    final directoryPath =
                                        directorySnapshot.data ?? '正在读取…';
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.54,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: kInkSecondary.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '应用内备份位置',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            directoryPath,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(height: 1.5),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
                                const _SectionHeader(
                                  title: '立即操作',
                                  subtitle: '常用流程只保留两步：生成加密备份并分享，或从已有备份恢复。',
                                ),
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
                                            onPressed: _submitting
                                                ? null
                                                : _createBackup,
                                            style: FilledButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons.backup_outlined,
                                            ),
                                            label: const Text('生成加密备份并分享'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: buttonWidth,
                                          child: OutlinedButton.icon(
                                            onPressed: _submitting
                                                ? null
                                                : _restoreFromPicker,
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
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
                          ),
                          GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionHeader(
                                  title: '最近备份',
                                  subtitle:
                                      '即使你上次没有保存到外部文件，也可以直接在这里重新生成加密分享文件，或恢复应用内副本。',
                                ),
                                const SizedBox(height: 14),
                                if (snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    backups.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (backups.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.54,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: kInkSecondary.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '还没有应用内备份，先生成一份。',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(height: 1.5),
                                    ),
                                  )
                                else
                                  ...backups.map(
                                    (record) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _BackupRecordCard(
                                        record: record,
                                        sizeLabel: _formatFileSize(
                                          record.sizeInBytes,
                                        ),
                                        onShare: _submitting
                                            ? null
                                            : () => _shareBackup(record),
                                        onRestore: _submitting
                                            ? null
                                            : () => _restoreFromRecord(record),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: kInkSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupRecordCard extends StatelessWidget {
  final BackupRecord record;
  final String sizeLabel;
  final VoidCallback? onShare;
  final VoidCallback? onRestore;

  const _BackupRecordCard({
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
              OutlinedButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('恢复此备份'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
