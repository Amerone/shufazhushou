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
              onBack: () => context.pop(),
            ),
            Expanded(
              child: asyncTemplates.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (templates) => templates.isEmpty
                    ? const EmptyState(message: '暂无课堂模板')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                        itemCount: templates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final t = templates[i];
                          return GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                t.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${t.startTime} – ${t.endTime}',
                                  style: TextStyle(color: kInkSecondary.withValues(alpha: 0.8)),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: kRed),
                                onPressed: () async {
                                  final ok = await AppToast.showConfirm(
                                      context, '确认删除模板"${t.name}"？');
                                  if (!ok) return;
                                  await ref.read(classTemplateDaoProvider)
                                      .delete(t.id);
                                  ref.read(classTemplateProvider.notifier).reload();
                                },
                              ),
                              onTap: () => _showForm(context, ref, t),
                            ),
                          );
                        },
                      ),
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

  void _showForm(BuildContext context, WidgetRef ref, ClassTemplate? t) {
    final nameCtrl = TextEditingController(text: t?.name ?? '');
    TimeOfDay startTime = parseTime(t?.startTime ?? '09:00');
    TimeOfDay endTime = parseTime(t?.endTime ?? '10:00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (stCtx, setSheetState) => GlassCard(
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
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
                t == null ? '新增课堂模板' : '编辑课堂模板',
                style: Theme.of(stCtx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl, 
                decoration: InputDecoration(
                  labelText: '模板名称',
                  hintText: '如：早班、晚班',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
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
                        fillColor: Colors.white.withValues(alpha: 0.5),
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
                        fillColor: Colors.white.withValues(alpha: 0.5),
                      ),
                      child: Text(formatTime(endTime), style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                  // 检查重复
                  final existing = ref.read(classTemplateProvider).valueOrNull ?? [];
                  final dup = existing.any((e) =>
                      e.id != (t?.id ?? '') &&
                      e.startTime == startStr &&
                      e.endTime == endStr);
                  if (dup) {
                    AppToast.showError(stCtx, '已存在相同时间段的模板');
                    return;
                  }

                  final dao = ref.read(classTemplateDaoProvider);
                  final now = DateTime.now().millisecondsSinceEpoch;
                  if (t == null) {
                    await dao.insert(ClassTemplate(
                      id: const Uuid().v4(),
                      name: name,
                      startTime: startStr,
                      endTime: endStr,
                      createdAt: now,
                    ));
                  } else {
                    await dao.update(t.copyWith(
                      name: name,
                      startTime: startStr,
                      endTime: endStr,
                    ));
                  }
                  ref.read(classTemplateProvider.notifier).reload();
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
                child: const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}