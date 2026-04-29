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
import '../widgets/student_import_widgets.dart';

class StudentImportScreen extends ConsumerStatefulWidget {
  final ImportPreview? initialPreview;

  const StudentImportScreen({super.key, this.initialPreview});

  @override
  ConsumerState<StudentImportScreen> createState() =>
      _StudentImportScreenState();
}

class _StudentImportScreenState extends ConsumerState<StudentImportScreen> {
  ImportPreview? _preview;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _preview = widget.initialPreview;
  }

  Future<void> _pick({bool clearExistingPreview = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (clearExistingPreview) {
        _preview = null;
      }
    });
    try {
      final existing =
          ref
              .read(studentProvider)
              .valueOrNull
              ?.map((m) => m.student)
              .toList() ??
          [];
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
    if (_loading || _preview == null) return;

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
    final previewStudents =
        preview?.toInsert.take(5).toList() ?? const <Student>[];
    final remainingPreviewCount = preview == null
        ? 0
        : preview.toInsert.length - previewStudents.length;
    final silentSkipped = preview == null
        ? 0
        : preview.skipped - preview.errors.length;
    final issueCount = preview?.errors.length ?? 0;
    final confirmDisabledReason = _loading
        ? '正在处理'
        : preview == null
        ? '先选择 Excel 文件'
        : preview.toInsert.isEmpty
        ? '没有可导入记录'
        : null;
    final importState = preview == null
        ? ('等待文件', '选择后先预览。', kPrimaryBlue)
        : preview.toInsert.isEmpty
        ? ('暂不可导入', '没有可写入记录。', kOrange)
        : issueCount > 0
        ? ('可导入', '只写入有效记录。', kSealRed)
        : ('可导入', '预览已通过。', kGreen);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '批量导入学生',
              subtitle: '预览后写入学生档案。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                              child: const Icon(
                                Icons.upload_file_outlined,
                                color: kPrimaryBlue,
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '导入流程',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '选文件、看预览、确认导入。',
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
                            ImportStepChip(index: '1', text: '选文件'),
                            ImportStepChip(index: '2', text: '看预览'),
                            ImportStepChip(index: '3', text: '导入'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const GuideLine(
                          icon: Icons.table_view_outlined,
                          text: '建议使用系统模板，确认“姓名”列存在。',
                        ),
                        const GuideLine(
                          icon: Icons.rule_folder_outlined,
                          text: '空姓名、重复记录不会写入。',
                        ),
                        const GuideLine(
                          icon: Icons.tips_and_updates_outlined,
                          text: '问题行会留在预览中。',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: Semantics(
                            container: true,
                            button: true,
                            enabled: !_loading,
                            label: _loading ? '正在处理文件' : '选择 Excel 文件并预览',
                            onTap: _loading
                                ? null
                                : () => _pick(
                                    clearExistingPreview: preview != null,
                                  ),
                            child: ExcludeSemantics(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: _loading
                                    ? null
                                    : () => _pick(
                                        clearExistingPreview: preview != null,
                                      ),
                                icon: const Icon(Icons.upload_file_outlined),
                                label: Text(_loading ? '处理中...' : '选文件导入'),
                              ),
                            ),
                          ),
                        ),
                        if (_loading) ...[
                          const SizedBox(height: 8),
                          Text(
                            '正在生成预览。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kInkSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 16),
                    ImportStatusCard(
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
                          ImportSectionHeader(
                            title: '预览结果',
                            subtitle: '核对后导入。',
                            trailing: '共 ${preview.total} 行',
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final itemWidth = width < 340
                                  ? width
                                  : width < 640
                                  ? (width - 12) / 2
                                  : (constraints.maxWidth - 36) / 4;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: itemWidth,
                                    child: ImportMetric(
                                      label: '总行数',
                                      value: '${preview.total}',
                                      color: kPrimaryBlue,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: ImportMetric(
                                      label: '可导入',
                                      value: '${preview.toInsert.length}',
                                      color: kGreen,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: ImportMetric(
                                      label: '跳过',
                                      value: '${preview.skipped}',
                                      color: kOrange,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: ImportMetric(
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
                              (entry) => ImportIssueLine(
                                index: entry.key + 1,
                                message: entry.value,
                              ),
                            ),
                          ],
                          if (silentSkipped > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: kOrange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '另外有 $silentSkipped 条记录因同名且家长信息一致而自动跳过。',
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
                            ImportSectionHeader(
                              title: '待导入名单',
                              subtitle: '展示即将写入的部分学员，便于快速抽查家长信息和课时单价。',
                              trailing: '预览前 ${previewStudents.length} 条',
                            ),
                            const SizedBox(height: 12),
                            ...previewStudents.map(
                              (student) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ImportStudentTile(student: student),
                              ),
                            ),
                            if (remainingPreviewCount > 0)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: kPrimaryBlue.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '另有 $remainingPreviewCount 人待导入。',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
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
                          ImportSectionHeader(
                            title: '确认导入',
                            subtitle: '只写入有效学生。',
                            trailing: preview.toInsert.isEmpty ? '待处理' : '准备就绪',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            preview.toInsert.isEmpty
                                ? '没有可导入记录。'
                                : '将写入 ${preview.toInsert.length} 位学生。',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ImportMetaBadge(
                                icon: Icons.person_add_alt_1_outlined,
                                label: '将新增 ${preview.toInsert.length} 人',
                                color: kGreen,
                              ),
                              ImportMetaBadge(
                                icon: Icons.warning_amber_outlined,
                                label: issueCount > 0
                                    ? '需关注 $issueCount 项'
                                    : '无错误项',
                                color: issueCount > 0 ? kSealRed : kPrimaryBlue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 420;
                              final buttonWidth = compact
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 12) / 2;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: buttonWidth,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      onPressed: _loading
                                          ? null
                                          : () => _pick(
                                              clearExistingPreview: true,
                                            ),
                                      icon: const Icon(Icons.refresh_outlined),
                                      label: const Text('重新选择'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: buttonWidth,
                                    child: Semantics(
                                      container: true,
                                      button: true,
                                      enabled: confirmDisabledReason == null,
                                      label: confirmDisabledReason == null
                                          ? '确认导入 ${preview.toInsert.length} 位学生'
                                          : '确认导入不可用，$confirmDisabledReason',
                                      onTap: confirmDisabledReason == null
                                          ? _confirm
                                          : null,
                                      child: ExcludeSemantics(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                          ),
                                          onPressed:
                                              confirmDisabledReason == null
                                              ? _confirm
                                              : null,
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          label: Text(
                                            _loading ? '处理中...' : '确认导入',
                                          ),
                                        ),
                                      ),
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
