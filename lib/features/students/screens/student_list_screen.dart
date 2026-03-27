import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/dao/student_dao.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncStudents = ref.watch(studentProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: asyncStudents.whenOrNull(data: (list) => '学生档案 (${list.length})') ?? '学生档案',
              subtitle: '按姓名或家长电话快速查找，支持新增和批量导入。',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderActionButton(
                    icon: Icons.upload_file_outlined,
                    tooltip: '批量导入',
                    onPressed: () => context.push('/students/import'),
                  ),
                  const SizedBox(width: 10),
                  _HeaderActionButton(
                    icon: Icons.add,
                    tooltip: '新增学生',
                    onPressed: () => context.push('/students/create'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: kSealRed,
                onRefresh: () async {
                  await ref.read(studentProvider.notifier).reload();
                },
                child: asyncStudents.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('加载失败：$e')),
                  data: (list) {
                    final filtered = _query.isEmpty
                        ? list
                        : list.where((item) {
                            final student = item.student;
                            return student.name.contains(_query) ||
                                (student.parentPhone?.contains(_query) ?? false) ||
                                (student.parentName?.contains(_query) ?? false);
                          }).toList();
                    final activeCount = list.where((item) => item.student.status == 'active').length;
                    final suspendedCount = list.length - activeCount;

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              TextField(
                                decoration: const InputDecoration(
                                  hintText: '搜索姓名、家长姓名或电话',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (value) => setState(() => _query = value.trim()),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StudentStatCard(
                                      label: '在读学生',
                                      value: '$activeCount',
                                      color: kPrimaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StudentStatCard(
                                      label: '休学学生',
                                      value: '$suspendedCount',
                                      color: kOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (filtered.isEmpty)
                          _buildEmptyState()
                        else ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 10),
                            child: Text(
                              _query.isEmpty ? '全部学生' : '搜索结果',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          ..._buildStudentCards(filtered),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_query.isNotEmpty) {
      return const EmptyState(message: '没有找到匹配的学生');
    }

    return EmptyState(
      message: '还没有学生档案，先添加一位学生开始记录。',
      actionLabel: '新增学生',
      onAction: () => context.push('/students/create'),
    );
  }

  List<Widget> _buildStudentCards(List<StudentWithMeta> filtered) {
    final displayNames = buildDisplayNameMap(filtered.map((item) => item.student).toList());

    return [
      for (var index = 0; index < filtered.length; index++) ...[
        _StudentCard(meta: filtered[index], displayNames: displayNames),
        if (index != filtered.length - 1) const SizedBox(height: 12),
      ],
    ];
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: kPrimaryBlue),
          ),
        ),
      ),
    );
  }
}

class _StudentStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StudentStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'NotoSansSC',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentWithMeta meta;
  final Map<String, String> displayNames;

  const _StudentCard({
    required this.meta,
    required this.displayNames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student = meta.student;
    final isSuspended = student.status != 'active';
    final accentColor = isSuspended ? kOrange : kPrimaryBlue;
    final parentLine = [
      if (student.parentName?.isNotEmpty ?? false) student.parentName!,
      if (student.parentPhone?.isNotEmpty ?? false) student.parentPhone!,
    ].join(' · ');

    return GlassCard(
      onTap: () => context.push('/students/${student.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSuspended ? Icons.pause_circle_outline : Icons.person_outline,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayNames[student.id] ?? student.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (parentLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(parentLine, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isSuspended ? '休学' : '在读',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StudentInfoChip(
                icon: Icons.payments_outlined,
                label: '课时单价 ¥${student.pricePerClass.toStringAsFixed(0)}',
              ),
              _StudentInfoChip(
                icon: Icons.history_outlined,
                label: meta.lastAttendanceDate == null ? '暂无上课记录' : '最近上课 ${meta.lastAttendanceDate}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StudentInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kInkSecondary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
