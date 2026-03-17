import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/class_template.dart';
import '../../../core/providers/class_template_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/time_wheel_picker.dart';

class TemplateScreen extends ConsumerWidget {
  const TemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplates = ref.watch(classTemplateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('课堂模板')),
      body: asyncTemplates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (templates) => templates.isEmpty
            ? const EmptyState(message: '暂无课堂模板')
            : ListView.builder(
                itemCount: templates.length,
                itemBuilder: (_, i) {
                  final t = templates[i];
                  return ListTile(
                    title: Text(t.name),
                    subtitle: Text('${t.startTime} – ${t.endTime}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
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
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, ref, null),
        child: const Icon(Icons.add),
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
      builder: (sheetCtx) => StatefulBuilder(
        builder: (stCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 8,
              bottom: MediaQuery.of(stCtx).viewInsets.bottom + MediaQuery.of(stCtx).padding.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kInkSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '模板名称')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimeWheelPicker(
                        context: stCtx,
                        initialTime: startTime,
                        label: '开始时间',
                      );
                      if (picked != null) setSheetState(() => startTime = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '开始时间'),
                      child: Text(formatTime(startTime)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimeWheelPicker(
                        context: stCtx,
                        initialTime: endTime,
                        label: '结束时间',
                      );
                      if (picked != null) setSheetState(() => endTime = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '结束时间'),
                      child: Text(formatTime(endTime)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
