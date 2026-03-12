import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/utils/toast.dart';

class StudentFormScreen extends ConsumerStatefulWidget {
  final String? studentId;
  const StudentFormScreen({super.key, this.studentId});

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _status = 'active';
  Student? _original;
  bool _loading = false;
  bool _priceWarningShown = false;

  bool get _isEdit => widget.studentId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadStudent();
  }

  Future<void> _loadStudent() async {
    final list = ref.read(studentProvider).valueOrNull ?? [];
    final meta = list.where((m) => m.student.id == widget.studentId).firstOrNull;
    if (meta == null) return;

    final s = meta.student;
    _original = s;
    _nameCtrl.text = s.name;
    _parentNameCtrl.text = s.parentName ?? '';
    _parentPhoneCtrl.text = s.parentPhone ?? '';
    _priceCtrl.text = s.pricePerClass.toStringAsFixed(0);
    _noteCtrl.text = s.note ?? '';
    setState(() => _status = s.status);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final dao = ref.read(studentDaoProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      final price = double.parse(_priceCtrl.text.trim());

      if (_isEdit && _original != null) {
        final updated = _original!.copyWith(
          name: _nameCtrl.text.trim(),
          parentName: _parentNameCtrl.text.trim().isEmpty ? null : _parentNameCtrl.text.trim(),
          parentPhone: _parentPhoneCtrl.text.trim().isEmpty ? null : _parentPhoneCtrl.text.trim(),
          pricePerClass: price,
          status: _status,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          updatedAt: now,
        );
        await dao.update(updated);
      } else {
        final student = Student(
          id: const Uuid().v4(),
          name: _nameCtrl.text.trim(),
          parentName: _parentNameCtrl.text.trim().isEmpty ? null : _parentNameCtrl.text.trim(),
          parentPhone: _parentPhoneCtrl.text.trim().isEmpty ? null : _parentPhoneCtrl.text.trim(),
          pricePerClass: price,
          status: _status,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await dao.insert(student);
      }

      await ref.read(studentProvider.notifier).reload();
      if (_isEdit) ref.invalidate(feeSummaryProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await AppToast.showConfirm(context, '确认删除该学生？相关出勤和缴费记录会一并删除。');
    if (!confirm) return;

    setState(() => _loading = true);
    try {
      await ref.read(studentDaoProvider).delete(widget.studentId!);
      await ref.read(studentProvider.notifier).reload();
      invalidateAfterStudentDelete(ref);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑学生' : '新增学生'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '姓名 *'),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入姓名' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _parentNameCtrl,
              decoration: const InputDecoration(labelText: '家长姓名'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _parentPhoneCtrl,
              decoration: const InputDecoration(labelText: '家长电话'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(labelText: '单价（元/节）*'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入单价';
                if (double.tryParse(v.trim()) == null) return '请输入有效数字';
                return null;
              },
              onChanged: (v) {
                if (!_isEdit || _original == null || _priceWarningShown) return;
                final newPrice = double.tryParse(v.trim());
                if (newPrice != null && newPrice != _original!.pricePerClass) {
                  _priceWarningShown = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('单价调整仅对新出勤记录生效')),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: '备注'),
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_original?.id ?? 'new'),
              initialValue: _status,
              decoration: const InputDecoration(labelText: '状态'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('在读')),
                DropdownMenuItem(value: 'suspended', child: Text('休学')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: Text(_loading ? '保存中...' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
