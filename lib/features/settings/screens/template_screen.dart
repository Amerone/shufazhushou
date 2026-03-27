import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/class_template.dart';
import '../../../core/providers/class_template_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '课堂模板',
              subtitle: '预设常用上课时段，记课时可直接快速选择。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: asyncTemplates.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (templates) {
                  if (templates.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                      children: const [
                        GlassCard(
                          padding: EdgeInsets.all(18),
                          child: EmptyState(message: '暂无课堂模板'),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                    itemCount: templates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final template = templates[i];
                      return GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: kPrimaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.schedule_outlined, color: kPrimaryBlue),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    template.name,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${template.startTime} - ${template.endTime}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showForm(context, ref, template),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: kRed),
                              onPressed: () async {
                                final ok = await AppToast.showConfirm(context, '确认删除模板“${template.name}”？');
                                if (!ok) return;
                                await ref.read(classTemplateDaoProvider).delete(template.id);
                                ref.read(classTemplateProvider.notifier).reload();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('新增模板'),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, ClassTemplate? template) {
    final nameCtrl = TextEditingController(text: template?.name ?? '');
    TimeOfDay startTime = parseTime(template?.startTime ?? '09:00');
    TimeOfDay endTime = parseTime(template?.endTime ?? '10:00');

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
                bottom: MediaQuery.of(stCtx).viewInsets.bottom + MediaQuery.of(stCtx).padding.bottom + 16,
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
                    style: Theme.of(stCtx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '为常用上课时段创建快捷入口，记课时可以直接套用。',
                    style: Theme.of(stCtx).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '模板名称',
                      hintText: '例如：早班、晚班、周末提高班',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.56),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final picked = await showTimeWheelPicker(
                              context: stCtx,
                              initialTime: startTime,
                              label: '开始时间',
                            );
                            if (picked != null) setSheetState(() => startTime = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: '开始时间',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.56),
                            ),
                            child: Text(formatTime(startTime), style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final picked = await showTimeWheelPicker(
                              context: stCtx,
                              initialTime: endTime,
                              label: '结束时间',
                            );
                            if (picked != null) setSheetState(() => endTime = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: '结束时间',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.56),
                            ),
                            child: Text(formatTime(endTime), style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
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

                      final existing = ref.read(classTemplateProvider).valueOrNull ?? [];
                      final hasDuplicate = existing.any(
                        (item) => item.id != (template?.id ?? '') && item.startTime == startStr && item.endTime == endStr,
                      );
                      if (hasDuplicate) {
                        AppToast.showError(stCtx, '已存在相同时间段的模板');
                        return;
                      }

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
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    },
                    child: const Text('保存模板'),
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
