import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/dao/class_template_dao.dart';
import '../../../core/models/class_template.dart';
import '../../../core/providers/class_template_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/time_wheel_picker.dart';

class TemplateScreen extends ConsumerWidget {
  const TemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplates = ref.watch(classTemplateProvider);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final horizontalPadding = MediaQuery.sizeOf(context).width < 390
        ? 16.0
        : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '课堂模板',
              subtitle: '记课时可快速套用。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: AsyncValueWidget<List<ClassTemplate>>(
                value: asyncTemplates,
                onRetry: () {
                  ref.read(classTemplateProvider.notifier).reload();
                },
                builder: (templates) {
                  final orderedTemplates = List<ClassTemplate>.of(templates)
                    ..sort((left, right) {
                      final leftBuiltin = _isBuiltinTemplate(left);
                      final rightBuiltin = _isBuiltinTemplate(right);
                      if (leftBuiltin != rightBuiltin) {
                        return leftBuiltin ? -1 : 1;
                      }
                      return left.createdAt.compareTo(right.createdAt);
                    });

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      4,
                      horizontalPadding,
                      120,
                    ),
                    children: [
                      GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '内置模板',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '已内置周内与周末常用时段。若你误删了默认模板，可一键补齐。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            const Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _TemplateTag('周内 18:00-19:00'),
                                _TemplateTag('周内 19:00-20:00'),
                                _TemplateTag('周末 08:30-09:30'),
                                _TemplateTag('周末 09:30-10:30'),
                                _TemplateTag('周末 10:30-11:30'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final inserted = await ref
                                      .read(classTemplateProvider.notifier)
                                      .ensureBuiltinTemplates(force: true);
                                  if (!context.mounted) return;
                                  if (inserted == 0) {
                                    AppToast.showSuccess(
                                      context,
                                      '默认模板已完整，无需补齐。',
                                    );
                                    return;
                                  }
                                  AppToast.showSuccess(
                                    context,
                                    '已补齐 $inserted 个默认模板。',
                                  );
                                },
                                icon: const Icon(Icons.restore_outlined),
                                label: const Text('补齐默认模板'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (orderedTemplates.isEmpty)
                        const GlassCard(
                          padding: EdgeInsets.all(18),
                          child: EmptyState(message: '暂无课堂模板'),
                        )
                      else
                        ...orderedTemplates.map((template) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TemplateCard(
                              template: template,
                              onEdit: () => _showForm(context, ref, template),
                              onDelete: () async {
                                final ok = await AppToast.showConfirm(
                                  context,
                                  '确认删除模板“${template.name}”？',
                                );
                                if (!ok) return;
                                await ref
                                    .read(classTemplateDaoProvider)
                                    .delete(template.id);
                                ref
                                    .read(classTemplateProvider.notifier)
                                    .reload();
                              },
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding + 80),
        child: FloatingActionButton.extended(
          onPressed: () {
            unawaited(InteractionFeedback.selection(context));
            _showForm(context, ref, null);
          },
          icon: const Icon(Icons.add),
          label: const Text('新增模板'),
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, ClassTemplate? template) {
    final nameCtrl = TextEditingController(text: template?.name ?? '');
    TimeOfDay startTime = parseTime(template?.startTime ?? '09:00');
    TimeOfDay endTime = parseTime(template?.endTime ?? '10:00');
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (stCtx, setSheetState) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.zero,
            child: GlassCard(
              margin: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom:
                    MediaQuery.of(stCtx).viewInsets.bottom +
                    MediaQuery.of(stCtx).padding.bottom +
                    16,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: kInkSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    template == null ? '新增课堂模板' : '编辑课堂模板',
                    style: Theme.of(stCtx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '模板名称',
                      hintText: '例如：晚班',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.56),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 360;
                      final fieldWidth = compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: _TemplateTimeField(
                              label: '开始时间',
                              value: formatTime(startTime),
                              onTap: () async {
                                final picked = await showTimeWheelPicker(
                                  context: stCtx,
                                  initialTime: startTime,
                                  label: '开始时间',
                                );
                                if (picked != null) {
                                  setSheetState(() => startTime = picked);
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _TemplateTimeField(
                              label: '结束时间',
                              value: formatTime(endTime),
                              onTap: () async {
                                final picked = await showTimeWheelPicker(
                                  context: stCtx,
                                  initialTime: endTime,
                                  label: '结束时间',
                                );
                                if (picked != null) {
                                  setSheetState(() => endTime = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              AppToast.showError(stCtx, '请输入模板名称');
                              return;
                            }

                            final startStr = formatTime(startTime);
                            final endStr = formatTime(endTime);
                            if (endStr.compareTo(startStr) <= 0) {
                              AppToast.showError(stCtx, '结束时间必须晚于开始时间');
                              return;
                            }

                            final existing =
                                ref.read(classTemplateProvider).valueOrNull ??
                                [];
                            final hasDuplicate = existing.any(
                              (item) =>
                                  item.id != (template?.id ?? '') &&
                                  item.startTime == startStr &&
                                  item.endTime == endStr,
                            );
                            if (hasDuplicate) {
                              AppToast.showError(stCtx, '已存在相同时间段的模板');
                              return;
                            }

                            setSheetState(() => saving = true);
                            try {
                              final dao = ref.read(classTemplateDaoProvider);
                              final now = DateTime.now().millisecondsSinceEpoch;
                              if (template == null) {
                                await dao.insert(
                                  ClassTemplate(
                                    id: const Uuid().v4(),
                                    name: name,
                                    startTime: startStr,
                                    endTime: endStr,
                                    createdAt: now,
                                  ),
                                );
                              } else {
                                await dao.update(
                                  template.copyWith(
                                    name: name,
                                    startTime: startStr,
                                    endTime: endStr,
                                  ),
                                );
                              }

                              ref.read(classTemplateProvider.notifier).reload();
                              if (!sheetCtx.mounted) return;
                              AppToast.showSuccess(
                                context,
                                template == null ? '模板已新增' : '模板已更新',
                              );
                              Navigator.of(sheetCtx).pop();
                            } catch (error) {
                              if (stCtx.mounted) {
                                AppToast.showError(stCtx, error.toString());
                              }
                            } finally {
                              if (stCtx.mounted) {
                                setSheetState(() => saving = false);
                              }
                            }
                          },
                    child: Text(saving ? '保存中...' : '保存模板'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isBuiltinTemplate(ClassTemplate template) {
  return builtinClassTemplateSeeds.any(
    (seed) =>
        seed.name == template.name &&
        seed.startTime == template.startTime &&
        seed.endTime == template.endTime,
  );
}

class _TemplateCard extends StatelessWidget {
  final ClassTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final builtin = _isBuiltinTemplate(template);
    final templateSummary = '${template.startTime} - ${template.endTime}';

    final leading = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.schedule_outlined, color: kPrimaryBlue),
    );

    final title = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          template.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (builtin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kSealRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '内置',
              style: theme.textTheme.bodySmall?.copyWith(
                color: kSealRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );

    final content = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 4),
          Text(templateSummary, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    final editAction = OutlinedButton.icon(
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('编辑'),
    );
    final deleteAction = OutlinedButton.icon(
      onPressed: onDelete,
      style: OutlinedButton.styleFrom(foregroundColor: kRed),
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('删除'),
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [leading, const SizedBox(width: 14), content],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: editAction,
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: deleteAction,
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              leading,
              const SizedBox(width: 14),
              content,
              const SizedBox(width: 12),
              Tooltip(
                message: '编辑模板',
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              ),
              Tooltip(
                message: '删除模板',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: kRed),
                  onPressed: onDelete,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateTimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TemplateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label，当前 $value',
      hint: '选择时间',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.56),
            ),
            child: Text(value, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

class _TemplateTag extends StatelessWidget {
  final String label;

  const _TemplateTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: kPrimaryBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
