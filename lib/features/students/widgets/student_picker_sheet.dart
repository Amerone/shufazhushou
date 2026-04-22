import 'dart:async';

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
  static const List<String> _errorPrefixes = <String>[
    'Exception: ',
    'FormatException: ',
    'StateError: ',
    'Bad state: ',
  ];

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

  int _compareStudents(StudentWithMeta a, StudentWithMeta b) {
    final aActive = a.student.status == 'active';
    final bActive = b.student.status == 'active';
    if (aActive != bActive) {
      return aActive ? -1 : 1;
    }

    final aLast = a.lastAttendanceDate;
    final bLast = b.lastAttendanceDate;
    if (aLast != null && bLast != null && aLast != bLast) {
      return bLast.compareTo(aLast);
    }
    if (aLast != null && bLast == null) return -1;
    if (aLast == null && bLast != null) return 1;
    if (a.student.createdAt != b.student.createdAt) {
      return b.student.createdAt.compareTo(a.student.createdAt);
    }
    return a.student.name.compareTo(b.student.name);
  }

  String _attendanceHint(StudentWithMeta meta) {
    if (meta.lastAttendanceDate == null || meta.lastAttendanceDate!.isEmpty) {
      return '未记过课';
    }
    return '最近上课 ${meta.lastAttendanceDate}';
  }

  String _formatError(Object error) {
    var text = error.toString().trim();
    for (final prefix in _errorPrefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
      }
    }
    return text.isEmpty ? '请稍后重试。' : text;
  }

  Future<void> _openStudentRoute(String route) async {
    await InteractionFeedback.pageTurn(context);
    if (!mounted) return;
    final router = GoRouter.of(context);
    await Navigator.of(context).maybePop();
    router.push(route);
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
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索学生姓名、家长或电话',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          onPressed: () {
                            unawaited(InteractionFeedback.selection(context));
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
                error: (error, _) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kRed.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '加载学生失败：${_formatError(error)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: kRed,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            unawaited(InteractionFeedback.selection(context));
                            ref.invalidate(studentProvider);
                          },
                          icon: const Icon(Icons.refresh_outlined, size: 18),
                          label: const Text('重试'),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (students) {
                  final visibleStudents =
                      students
                          .where(
                            (item) =>
                                !widget.activeOnly ||
                                item.student.status == 'active',
                          )
                          .where((item) => _matchesQuery(item.student))
                          .toList()
                        ..sort(_compareStudents);
                  final displayNames = ref.watch(studentDisplayNameMapProvider);

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
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 360;
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
                                      onPressed: () =>
                                          _openStudentRoute('/students/import'),
                                      icon: const Icon(
                                        Icons.upload_file_outlined,
                                      ),
                                      label: const Text('批量导入'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: buttonWidth,
                                    child: FilledButton.icon(
                                      onPressed: () =>
                                          _openStudentRoute('/students/create'),
                                      icon: const Icon(Icons.person_add_alt_1),
                                      label: const Text('新增学生'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_query.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryBlue.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: kPrimaryBlue.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            '已按最近上课排序，今天刚上课或最近常上的学生会排在前面。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kPrimaryBlue,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: visibleStudents.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
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

                            Future<void> selectStudent() async {
                              await InteractionFeedback.selection(context);
                              if (!context.mounted) return;
                              Navigator.of(context).pop(
                                StudentWithMeta(
                                  student,
                                  meta.lastAttendanceDate,
                                ),
                              );
                            }

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 420;
                                final avatar = Container(
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
                                );
                                final studentInfo = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (detailLine.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        detailLine,
                                        maxLines: compact ? 2 : 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _StudentMetaChip(
                                          icon: Icons.history_outlined,
                                          label: _attendanceHint(meta),
                                          color: meta.lastAttendanceDate == null
                                              ? kInkSecondary
                                              : kSealRed,
                                        ),
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
                                );
                                final action = _StudentPickerVisualAction(
                                  label: widget.actionLabel,
                                );

                                return Semantics(
                                  container: true,
                                  button: true,
                                  label: '$displayName ${widget.actionLabel}',
                                  onTap: selectStudent,
                                  child: ExcludeSemantics(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: selectStudent,
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.56,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(
                                              color: statusColor.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                          ),
                                          child: compact
                                              ? Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        avatar,
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: studentInfo,
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: action,
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  children: [
                                                    avatar,
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: studentInfo,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    action,
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
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
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 128,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentPickerVisualAction extends StatelessWidget {
  final String label;

  const _StudentPickerVisualAction({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_outward_outlined, size: 18, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
