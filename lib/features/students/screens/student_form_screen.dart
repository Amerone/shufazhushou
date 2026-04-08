import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/dao/student_dao.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

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

  bool get _isEdit => widget.studentId != null;

  InputDecoration _inputDecoration({
    required String label,
    String? hintText,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _syncStudentFromProvider(ref.read(studentProvider));
    }
  }

  void _syncStudentFromProvider(
    AsyncValue<List<StudentWithMeta>> asyncStudents,
  ) {
    if (!_isEdit || _original != null) return;

    final list = asyncStudents.valueOrNull ?? const <StudentWithMeta>[];
    final meta = list
        .where((m) => m.student.id == widget.studentId)
        .firstOrNull;
    if (meta == null) return;

    final s = meta.student;
    _nameCtrl.text = s.name;
    _parentNameCtrl.text = s.parentName ?? '';
    _parentPhoneCtrl.text = s.parentPhone ?? '';
    _priceCtrl.text = s.pricePerClass.toStringAsFixed(0);
    _noteCtrl.text = s.note ?? '';
    setState(() {
      _original = s;
      _status = s.status;
    });
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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final dao = ref.read(studentDaoProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      final price = double.parse(_priceCtrl.text.trim());

      if (_isEdit && _original != null) {
        final updated = _original!.copyWith(
          name: _nameCtrl.text.trim(),
          parentName: _parentNameCtrl.text.trim().isEmpty
              ? null
              : _parentNameCtrl.text.trim(),
          parentPhone: _parentPhoneCtrl.text.trim().isEmpty
              ? null
              : _parentPhoneCtrl.text.trim(),
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
          parentName: _parentNameCtrl.text.trim().isEmpty
              ? null
              : _parentNameCtrl.text.trim(),
          parentPhone: _parentPhoneCtrl.text.trim().isEmpty
              ? null
              : _parentPhoneCtrl.text.trim(),
          pricePerClass: price,
          status: _status,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await dao.insert(student);
      }

      invalidateAfterStudentChange(ref);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await AppToast.showConfirm(
      context,
      '确认删除该学生？相关出勤和缴费记录会一并删除。',
    );
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
    ref.listen<AsyncValue<List<StudentWithMeta>>>(studentProvider, (_, next) {
      _syncStudentFromProvider(next);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: _isEdit ? '编辑学生' : '新增学生',
              subtitle: _isEdit ? '更新档案信息、状态和课时价格。' : '创建新学生档案，便于后续记课和缴费。',
              onBack: () => context.pop(),
              trailing: _isEdit
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: kRed),
                      onPressed: _delete,
                    )
                  : null,
            ),
            Expanded(
              child: Form(
                key: _formKey,
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
                          Text(
                            '基础信息',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '姓名会直接用于点名、统计和导出报告展示。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: '学生姓名 *',
                              hintText: '请输入学生姓名',
                              icon: Icons.school_outlined,
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? '请输入姓名' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _parentNameCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: '家长姓名',
                              hintText: '选填，便于区分重名学员',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _parentPhoneCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: '家长电话',
                              hintText: '选填，便于后续联系',
                              icon: Icons.phone_outlined,
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '课程设置',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _priceCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: '单价（元/节）*',
                              hintText: '请输入每节课的收费标准',
                              icon: Icons.payments_outlined,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return '请输入单价';
                              if (double.tryParse(v.trim()) == null) {
                                return '请输入有效数字';
                              }
                              return null;
                            },
                          ),
                          if (_isEdit) ...[
                            const SizedBox(height: 10),
                            const _FormHint(
                              icon: Icons.info_outline,
                              text: '修改单价只会影响后续新增的出勤记录，历史记录金额保持不变。',
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            '学习状态',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 440;
                              final itemWidth = compact
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 12) / 2;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _statusOptions
                                    .map(
                                      (option) => SizedBox(
                                        width: itemWidth,
                                        child: _StatusOptionCard(
                                          option: option,
                                          selected: _status == option.value,
                                          onTap: () => setState(
                                            () => _status = option.value,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _noteCtrl,
                            decoration: _inputDecoration(
                              label: '备注',
                              hintText: '例如学习特点、请假说明等',
                              icon: Icons.sticky_note_2_outlined,
                            ),
                            maxLines: 3,
                            maxLength: 200,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _loading ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_loading ? '保存中...' : '保存学生档案'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _statusOptions = [
  _StatusOptionData(
    value: 'active',
    title: '在读',
    subtitle: '正常安排课程，并在统计中视为活跃学员',
    icon: Icons.auto_stories_outlined,
    color: kGreen,
  ),
  _StatusOptionData(
    value: 'suspended',
    title: '休学',
    subtitle: '暂不安排课程，仍保留历史课时和缴费档案',
    icon: Icons.pause_circle_outline,
    color: kOrange,
  ),
];

class _FormHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FormHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: kPrimaryBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: kPrimaryBlue),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOptionData {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatusOptionData({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _StatusOptionCard extends StatelessWidget {
  final _StatusOptionData option;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? option.color.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? option.color.withValues(alpha: 0.85)
                  : kInkSecondary.withValues(alpha: 0.14),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: selected ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(option.icon, color: option.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected ? option.color : null,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: option.color,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(option.subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
