import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/dao/student_dao.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/widgets/glass_card.dart';

class StudentPickerSheet extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final bool activeOnly;
  final String emptyMessage;
  final String actionLabel;

  const StudentPickerSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.activeOnly = false,
    this.emptyMessage = '还没有学生档案，请先新增或导入学生。',
  });

  @override
  ConsumerState<StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends ConsumerState<StudentPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(Student student) {
    if (_query.isEmpty) return true;
    return student.name.contains(_query) ||
        (student.parentName?.contains(_query) ?? false) ||
        (student.parentPhone?.contains(_query) ?? false);
  }

  Future<void> _openStudentRoute(String route) async {
    await InteractionFeedback.pageTurn(context);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!mounted) return;
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final asyncStudents = ref.watch(studentProvider);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.zero,
        child: GlassCard(
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: bottomInset + MediaQuery.of(context).padding.bottom + 16,
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
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索学生姓名、家长或电话',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _query = '';
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 16),
              asyncStudents.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('加载学生失败：$error'),
                ),
                data: (students) {
                  final visibleStudents = students
                      .where(
                        (item) =>
                            !widget.activeOnly ||
                            item.student.status == 'active',
                      )
                      .where((item) => _matchesQuery(item.student))
                      .toList(growable: false);
                  final displayNames = buildDisplayNameMap(
                    visibleStudents.map((item) => item.student).toList(),
                  );

                  if (visibleStudents.isEmpty) {
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.54),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: kInkSecondary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            _query.isEmpty
                                ? widget.emptyMessage
                                : '没有找到符合条件的学生。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (_query.isEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _openStudentRoute('/students/import'),
                                  icon: const Icon(Icons.upload_file_outlined),
                                  label: const Text('批量导入'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _openStudentRoute('/students/create'),
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('新增学生'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  }

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: visibleStudents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final meta = visibleStudents[index];
                        final student = meta.student;
                        final displayName =
                            displayNames[student.id] ?? student.name;
                        final detailLine = [
                          if (student.parentName?.isNotEmpty ?? false)
                            student.parentName!,
                          if (student.parentPhone?.isNotEmpty ?? false)
                            student.parentPhone!,
                        ].join(' · ');
                        final statusColor = student.status == 'active'
                            ? kGreen
                            : kOrange;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              await InteractionFeedback.selection(context);
                              if (!context.mounted) return;
                              Navigator.of(context).pop(
                                StudentWithMeta(
                                  student,
                                  meta.lastAttendanceDate,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.56),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.person_outline,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (detailLine.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            detailLine,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _StudentMetaChip(
                                              icon: Icons.payments_outlined,
                                              label:
                                                  '¥${student.pricePerClass.toStringAsFixed(0)}/节',
                                              color: kPrimaryBlue,
                                            ),
                                            _StudentMetaChip(
                                              icon: Icons.flag_outlined,
                                              label: student.status == 'active'
                                                  ? '在读'
                                                  : '休学',
                                              color: statusColor,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await InteractionFeedback.selection(
                                        context,
                                      );
                                      if (!context.mounted) return;
                                      Navigator.of(context).pop(
                                        StudentWithMeta(
                                          student,
                                          meta.lastAttendanceDate,
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.arrow_outward_outlined,
                                    ),
                                    label: Text(widget.actionLabel),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StudentMetaChip({
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
