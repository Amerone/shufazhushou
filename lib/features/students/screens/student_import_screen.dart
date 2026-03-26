import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/student.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/excel_importer.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class StudentImportScreen extends ConsumerStatefulWidget {
  const StudentImportScreen({super.key});

  @override
  ConsumerState<StudentImportScreen> createState() => _StudentImportScreenState();
}

class _StudentImportScreenState extends ConsumerState<StudentImportScreen> {
  ImportPreview? _preview;
  bool _loading = false;

  Future<void> _pick({bool clearExistingPreview = false}) async {
    setState(() {
      _loading = true;
      if (clearExistingPreview) {
        _preview = null;
      }
    });
    try {
      final existing = ref.read(studentProvider).valueOrNull?.map((m) => m.student).toList() ?? [];
      final preview = await ExcelImporter.pick(existing);
      if (preview != null && mounted) {
        setState(() => _preview = preview);
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (_preview == null) return;

    setState(() => _loading = true);
    try {
      await ExcelImporter.commit(_preview!, ref.read(studentDaoProvider));
      await ref.read(studentProvider.notifier).reload();
      if (mounted) {
        AppToast.showSuccess(context, '导入成功 ${_preview!.toInsert.length} 条');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;
    final previewStudents = preview?.toInsert.take(5).toList() ?? const <Student>[];
    final remainingPreviewCount = preview == null ? 0 : preview.toInsert.length - previewStudents.length;
    final silentSkipped = preview == null ? 0 : preview.skipped - preview.errors.length;
    final issueCount = preview?.errors.length ?? 0;
    final importState = preview == null
        ? ('等待选择文件', '先选择 Excel 文件，再查看导入预览。', kPrimaryBlue)
        : preview.toInsert.isEmpty
            ? ('暂不可导入', '当前没有可写入的学生记录，请先处理问题项。', kOrange)
            : issueCount > 0
                ? ('可导入但需留意', '存在需要校对的行，确认后只会导入有效记录。', kSealRed)
                : ('可以直接导入', '预览通过，可以一次性写入本次有效学生档案。', kGreen);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '批量导入学生',
              subtitle: '选择 Excel 文件后先预览，再一次性写入学生档案。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                children: [
                  GlassCard(
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
                              child: const Icon(Icons.upload_file_outlined, color: kPrimaryBlue),
                            ),
                            SizedBox(
                              width: 220,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '导入流程',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '先选文件，再看预览，最后确认入库。重复姓名会自动跳过，错误行不会写入。',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ImportStepChip(index: '1', text: '选择模板文件'),
                            _ImportStepChip(index: '2', text: '核对预览结果'),
                            _ImportStepChip(index: '3', text: '确认批量导入'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _GuideLine(
                          icon: Icons.table_view_outlined,
                          text: '建议使用系统模板整理列顺序，尤其确认“姓名”列存在。',
                        ),
                        const _GuideLine(
                          icon: Icons.rule_folder_outlined,
                          text: '预览会优先拦截空姓名和重复姓名，避免直接写入脏数据。',
                        ),
                        const _GuideLine(
                          icon: Icons.tips_and_updates_outlined,
                          text: '即使存在问题项，也只会导入有效行，错误记录会保留在预览中提示。',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _loading
                                ? null
                                : () => _pick(clearExistingPreview: preview != null),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: Text(_loading ? '处理中...' : '选择 Excel 文件'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 16),
                    _ImportStatusCard(
                      title: importState.$1,
                      subtitle: importState.$2,
                      color: importState.$3,
                      preview: preview,
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ImportSectionHeader(
                            title: '预览结果',
                            subtitle: '先确认总量、有效记录和问题数量，再决定是否导入。',
                            trailing: '共 ${preview.total} 行',
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 460;
                              final itemWidth = compact
                                  ? (constraints.maxWidth - 12) / 2
                                  : (constraints.maxWidth - 36) / 4;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: itemWidth,
                                    child: _ImportMetric(
                                      label: '总行数',
                                      value: '${preview.total}',
                                      color: kPrimaryBlue,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _ImportMetric(
                                      label: '可导入',
                                      value: '${preview.toInsert.length}',
                                      color: kGreen,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _ImportMetric(
                                      label: '跳过',
                                      value: '${preview.skipped}',
                                      color: kOrange,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _ImportMetric(
                                      label: '问题数',
                                      value: '$issueCount',
                                      color: issueCount > 0 ? kSealRed : kGreen,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (preview.errors.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('需要处理的问题', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 8),
                            ...preview.errors.asMap().entries.map(
                                  (entry) => _ImportIssueLine(
                                    index: entry.key + 1,
                                    message: entry.value,
                                  ),
                                ),
                          ],
                          if (silentSkipped > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: kOrange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '另外有 $silentSkipped 条记录因姓名重复而自动跳过。',
                                style: theme.textTheme.bodySmall?.copyWith(
                                      color: kOrange,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (previewStudents.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ImportSectionHeader(
                              title: '待导入名单',
                              subtitle: '展示即将写入的部分学员，便于快速抽查家长信息和课时单价。',
                              trailing: '预览前 ${previewStudents.length} 条',
                            ),
                            const SizedBox(height: 12),
                            ...previewStudents.map(
                              (student) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ImportStudentTile(student: student),
                              ),
                            ),
                            if (remainingPreviewCount > 0)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: kPrimaryBlue.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '还有 $remainingPreviewCount 位学生将在确认后一起导入。',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: kPrimaryBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ImportSectionHeader(
                            title: '确认导入',
                            subtitle: '确认按钮只会写入有效学生；重新选择会清空当前预览。',
                            trailing: preview.toInsert.isEmpty ? '待处理' : '准备就绪',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            preview.toInsert.isEmpty
                                ? '当前没有可导入的学生记录，请重新检查 Excel 内容。'
                                : '确认后将一次性写入 ${preview.toInsert.length} 位学生档案。',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ImportMetaBadge(
                                icon: Icons.person_add_alt_1_outlined,
                                label: '将新增 ${preview.toInsert.length} 人',
                                color: kGreen,
                              ),
                              _ImportMetaBadge(
                                icon: Icons.warning_amber_outlined,
                                label: issueCount > 0 ? '需关注 $issueCount 项' : '无错误项',
                                color: issueCount > 0 ? kSealRed : kPrimaryBlue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 420;
                              final buttonWidth =
                                  compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: buttonWidth,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      onPressed: _loading ? null : () => _pick(clearExistingPreview: true),
                                      icon: const Icon(Icons.refresh_outlined),
                                      label: const Text('重新选择'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: buttonWidth,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      onPressed: _loading || preview.toInsert.isEmpty ? null : _confirm,
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: Text(_loading ? '处理中...' : '确认导入'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GuideLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kInkSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ImportStepChip extends StatelessWidget {
  final String index;
  final String text;

  const _ImportStepChip({
    required this.index,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: kPrimaryBlue,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              index,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kPrimaryBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ImportStatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final ImportPreview preview;

  const _ImportStatusCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              preview.toInsert.isEmpty ? Icons.rule_outlined : Icons.fact_check_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _ImportSectionHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
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
              width: compact ? constraints.maxWidth : constraints.maxWidth - 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
              ),
              child: Text(trailing, style: theme.textTheme.bodySmall),
            ),
          ],
        );
      },
    );
  }
}

class _ImportMetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ImportMetaBadge({
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

class _ImportMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ImportMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'NotoSansSC',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportIssueLine extends StatelessWidget {
  final int index;
  final String message;

  const _ImportIssueLine({
    required this.index,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: kOrange,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kOrange),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportStudentTile extends StatelessWidget {
  final Student student;

  const _ImportStudentTile({required this.student});

  String _formatPrice(double value) {
    if (value <= 0) return '待补充';
    return value == value.truncateToDouble() ? '¥${value.toStringAsFixed(0)}' : '¥${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if ((student.parentName ?? '').trim().isNotEmpty) '家长 ${student.parentName!.trim()}',
      if ((student.parentPhone ?? '').trim().isNotEmpty) student.parentPhone!.trim(),
    ];
    final hasPrice = student.pricePerClass > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kPrimaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_outline, color: kPrimaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ImportMetaBadge(
                      icon: Icons.family_restroom_outlined,
                      label: details.isEmpty ? '未填写家长信息' : details.join(' · '),
                      color: kPrimaryBlue,
                    ),
                    _ImportMetaBadge(
                      icon: Icons.payments_outlined,
                      label: hasPrice ? _formatPrice(student.pricePerClass) : '待补充课时单价',
                      color: hasPrice ? kGreen : kOrange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
