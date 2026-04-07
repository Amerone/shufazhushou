import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/dao/student_dao.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/student_action_launcher.dart';

enum _StudentListFilter { all, active, suspended }

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _StudentListFilter _filter = _StudentListFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    setState(() => _query = value.trim());
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filter = _StudentListFilter.all;
    });
  }

  bool _matchesFilter(StudentWithMeta item) {
    return switch (_filter) {
      _StudentListFilter.all => true,
      _StudentListFilter.active => item.student.status == 'active',
      _StudentListFilter.suspended => item.student.status != 'active',
    };
  }

  bool _matchesQuery(Student student) {
    if (_query.isEmpty) return true;
    return student.name.contains(_query) ||
        (student.parentPhone?.contains(_query) ?? false) ||
        (student.parentName?.contains(_query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final asyncStudents = ref.watch(studentProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title:
                  asyncStudents.whenOrNull(
                    data: (list) => '学生档案 (${list.length})',
                  ) ??
                  '学生档案',
              subtitle: '新增、查找、进入学生档案',
            ),
            Expanded(
              child: RefreshIndicator(
                color: kSealRed,
                onRefresh: () async {
                  await ref.read(studentProvider.notifier).reload();
                },
                child: asyncStudents.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('加载失败：$e')),
                  data: (list) {
                    final filtered = list
                        .where((item) => _matchesFilter(item))
                        .where((item) => _matchesQuery(item.student))
                        .toList();
                    final activeCount = list
                        .where((item) => item.student.status == 'active')
                        .length;
                    final suspendedCount = list.length - activeCount;
                    final hasActiveFilter =
                        _query.isNotEmpty || _filter != _StudentListFilter.all;
                    final resultSummary = hasActiveFilter
                        ? '当前显示 ${filtered.length} / ${list.length} 位学生'
                        : '共 ${list.length} 位学生';

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 420;
                                  final buttonWidth = compact
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 12) / 2;

                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: buttonWidth,
                                        child: FilledButton.icon(
                                          onPressed: () {
                                            unawaited(
                                              InteractionFeedback.selection(
                                                context,
                                              ),
                                            );
                                            context.push('/students/create');
                                          },
                                          icon: const Icon(Icons.add),
                                          label: const Text('新增学生'),
                                        ),
                                      ),
                                      SizedBox(
                                        width: buttonWidth,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            unawaited(
                                              InteractionFeedback.selection(
                                                context,
                                              ),
                                            );
                                            context.push('/students/import');
                                          },
                                          icon: const Icon(
                                            Icons.upload_file_outlined,
                                          ),
                                          label: const Text('批量导入'),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _StudentSummaryPill(
                                    label: '在读 $activeCount',
                                    color: kPrimaryBlue,
                                  ),
                                  _StudentSummaryPill(
                                    label: '休学 $suspendedCount',
                                    color: kOrange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: '搜索姓名、家长姓名或电话',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: '清空搜索',
                                          onPressed: () {
                                            unawaited(
                                              InteractionFeedback.selection(
                                                context,
                                              ),
                                            );
                                            _clearQuery();
                                          },
                                          icon: const Icon(Icons.close),
                                        ),
                                ),
                                onChanged: _updateQuery,
                              ),
                              const SizedBox(height: 14),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SegmentedButton<_StudentListFilter>(
                                  segments: const [
                                    ButtonSegment(
                                      value: _StudentListFilter.all,
                                      icon: Icon(
                                        Icons.grid_view_rounded,
                                        size: 18,
                                      ),
                                      label: Text('全部'),
                                    ),
                                    ButtonSegment(
                                      value: _StudentListFilter.active,
                                      icon: Icon(
                                        Icons.verified_user_outlined,
                                        size: 18,
                                      ),
                                      label: Text('在读'),
                                    ),
                                    ButtonSegment(
                                      value: _StudentListFilter.suspended,
                                      icon: Icon(
                                        Icons.pause_circle_outline,
                                        size: 18,
                                      ),
                                      label: Text('休学'),
                                    ),
                                  ],
                                  selected: {_filter},
                                  showSelectedIcon: false,
                                  onSelectionChanged: (selection) {
                                    unawaited(
                                      InteractionFeedback.selection(context),
                                    );
                                    setState(() => _filter = selection.first);
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: kInkSecondary.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      hasActiveFilter
                                          ? Icons.filter_alt_outlined
                                          : Icons.people_outline,
                                      size: 18,
                                      color: kPrimaryBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        resultSummary,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: kPrimaryBlue,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (hasActiveFilter)
                                      TextButton(
                                        onPressed: () {
                                          unawaited(
                                            InteractionFeedback.selection(
                                              context,
                                            ),
                                          );
                                          _resetFilters();
                                        },
                                        child: const Text('重置筛选'),
                                      ),
                                  ],
                                ),
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
                              _query.isEmpty
                                  ? switch (_filter) {
                                      _StudentListFilter.all => '全部学生',
                                      _StudentListFilter.active => '在读学生',
                                      _StudentListFilter.suspended => '休学学生',
                                    }
                                  : '搜索结果',
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
    if (_query.isNotEmpty || _filter != _StudentListFilter.all) {
      return EmptyState(
        message: _query.isNotEmpty ? '没有找到匹配的学生' : '当前筛选条件下没有学生',
        actionLabel: '重置筛选',
        onAction: _resetFilters,
      );
    }

    return EmptyState(
      message: '还没有学生档案，先添加一位学生开始记录。',
      actionLabel: '新增学生',
      onAction: () => context.push('/students/create'),
    );
  }

  List<Widget> _buildStudentCards(List<StudentWithMeta> filtered) {
    final displayNames = buildDisplayNameMap(
      filtered.map((item) => item.student).toList(),
    );

    return [
      for (var index = 0; index < filtered.length; index++) ...[
        _StudentCard(meta: filtered[index], displayNames: displayNames),
        if (index != filtered.length - 1) const SizedBox(height: 12),
      ],
    ];
  }
}

class _StudentSummaryPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StudentSummaryPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentWithMeta meta;
  final Map<String, String> displayNames;

  const _StudentCard({required this.meta, required this.displayNames});

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
      onTap: () {
        unawaited(InteractionFeedback.pageTurn(context));
        context.push('/students/${student.id}');
      },
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
                  isSuspended
                      ? Icons.pause_circle_outline
                      : Icons.person_outline,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (parentLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(parentLine, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    unawaited(InteractionFeedback.selection(context));
                    context.push('/students/${student.id}/edit');
                  },
                  child: Ink(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: accentColor,
                    ),
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
                label: meta.lastAttendanceDate == null
                    ? '暂无上课记录'
                    : '最近上课 ${meta.lastAttendanceDate}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSuspended
                      ? '可继续查看历史记录，并在档案页调整状态。'
                      : '进入档案后可继续查看出勤、缴费和成长记录。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kInkSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 360;
                    final actionWidth = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.end,
                      children: [
                        SizedBox(
                          width: actionWidth,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await InteractionFeedback.selection(context);
                              if (!context.mounted) return;
                              await showStudentPaymentSheet(
                                context,
                                studentId: student.id,
                                studentName:
                                    displayNames[student.id] ?? student.name,
                                pricePerClass: student.pricePerClass,
                              );
                            },
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('记录缴费'),
                          ),
                        ),
                        SizedBox(
                          width: actionWidth,
                          child: FilledButton.tonalIcon(
                            onPressed: () {
                              unawaited(InteractionFeedback.pageTurn(context));
                              context.push('/students/${student.id}');
                            },
                            icon: const Icon(
                              Icons.arrow_outward_outlined,
                              size: 18,
                            ),
                            label: const Text('查看档案'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StudentInfoChip({required this.icon, required this.label});

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
