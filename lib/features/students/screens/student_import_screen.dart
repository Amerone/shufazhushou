import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/excel_importer.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';

class StudentImportScreen extends ConsumerStatefulWidget {
  const StudentImportScreen({super.key});

  @override
  ConsumerState<StudentImportScreen> createState() => _StudentImportScreenState();
}

class _StudentImportScreenState extends ConsumerState<StudentImportScreen> {
  ImportPreview? _preview;
  bool _loading = false;

  Future<void> _pick() async {
    setState(() => _loading = true);
    try {
      final existing = ref.read(studentProvider).valueOrNull?.map((m) => m.student).toList() ?? [];
      final preview = await ExcelImporter.pick(existing);
      if (preview != null) setState(() => _preview = preview);
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
    return Scaffold(
      appBar: AppBar(title: const Text('批量导入学生')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : _pick,
              icon: const Icon(Icons.upload_file),
              label: const Text('选择 Excel 文件'),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              Text('共 ${_preview!.total} 行，将导入 ${_preview!.toInsert.length} 条，跳过 ${_preview!.skipped} 条'),
              if (_preview!.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._preview!.errors.map(
                  (e) => Text(e, style: const TextStyle(color: kOrange, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading || _preview!.toInsert.isEmpty ? null : _confirm,
                child: const Text('确认导入'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
