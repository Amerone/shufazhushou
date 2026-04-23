import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/dao/student_dao.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../widgets/student_action_launcher.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _queryDebounce;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(studentListQueryProvider).text;
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    final normalized = value.trim();
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final current = ref.read(studentListQueryProvider);
      if (current.text == normalized) return;
      ref.read(studentListQueryProvider.notifier).state = current.copyWith(
        text: normalized,
      );
    });
  }

  void _clearQuery() {
    _queryDebounce?.cancel();
    _searchController.clear();
    final current = ref.read(studentListQueryProvider);
    ref.read(studentListQueryProvider.notifier).state = current.copyWith(
      text: '',
    );
  }

  void _resetFilters() {
    _queryDebounce?.cancel();
    _searchController.clear();
    ref.read(studentListQueryProvider.notifier).state = StudentListQuery.empty;
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
              subtitle: null,
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
                  error: (error, _) => _StudentListLoadError(
                    onRetry: () {
                      ref.invalidate(studentProvider);
                    },
                  ),
                  data: (_) {
                    final viewModel = ref.watch(studentListViewModelProvider);
                    final query = viewModel.query;

                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                          sliver: SliverToBoxAdapter(
                            child: _StudentListToolbar(
                              query: query,
                              searchController: _searchController,
                              activeCount: viewModel.activeCount,
                              suspendedCount: viewModel.suspendedCount,
                              filteredCount: viewModel.filtered.length,
                              totalCount: viewModel.totalCount,
                              onQueryChanged: _updateQuery,
                              onClearQuery: _clearQuery,
                              onResetFilters: _resetFilters,
                              onFilterChanged: (filter) {
                                final current = ref.read(
                                  studentListQueryProvider,
                                );
                                if (current.filter == filter) return;
                                ref
                                    .read(studentListQueryProvider.notifier)
                                    .state = current.copyWith(
                                  filter: filter,
                                );
                              },
                            ),
                          ),
                        ),
                        const SliverPadding(
                          padding: EdgeInsets.only(top: 16),
                          sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
                        ),
                        if (viewModel.filtered.isEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                            sliver: SliverToBoxAdapter(
                              child: _buildEmptyState(query),
                            ),
                          )
                        else ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(28, 0, 24, 10),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                query.text.isEmpty
                                    ? switch (query.filter) {
                                        StudentListFilter.all => '全部学生',
                                        StudentListFilter.active => '在读学生',
                                        StudentListFilter.suspended => '休学学生',
                                      }
                                    : '搜索结果',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                            sliver: _buildStudentListSliver(
                              filtered: viewModel.filtered,
                              displayNames: viewModel.displayNames,
                            ),
                          ),
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

  Widget _buildEmptyState(StudentListQuery query) {
    if (query.hasActiveFilter) {
      return EmptyState(
        message: query.text.isNotEmpty ? '没有找到“${query.text}”' : '没有符合当前筛选的学生',
        actionLabel: '重置筛选',
        onAction: _resetFilters,
      );
    }

    return EmptyState(
      message: '还没有学生档案',
      actionLabel: '新增学生',
      onAction: () => context.push('/students/create'),
    );
  }

  Widget _buildStudentListSliver({
    required List<StudentWithMeta> filtered,
    required Map<String, String> displayNames,
  }) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index.isOdd) {
          return const SizedBox(height: 12);
        }
        final item = filtered[index ~/ 2];
        return _StudentCard(meta: item, displayNames: displayNames);
      }, childCount: filtered.isEmpty ? 0 : filtered.length * 2 - 1),
    );
  }
}

class _StudentListLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _StudentListLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          child: EmptyState(
            message: '学员档案加载失败，请稍后重试。',
            actionLabel: '重新加载',
            onAction: onRetry,
          ),
        ),
      ),
    );
  }
}

class _StudentListToolbar extends StatelessWidget {
  final StudentListQuery query;
  final TextEditingController searchController;
  final int activeCount;
  final int suspendedCount;
  final int filteredCount;
  final int totalCount;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final VoidCallback onResetFilters;
  final ValueChanged<StudentListFilter> onFilterChanged;

  const _StudentListToolbar({
    required this.query,
    required this.searchController,
    required this.activeCount,
    required this.suspendedCount,
    required this.filteredCount,
    required this.totalCount,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onResetFilters,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final resultSummary = query.hasActiveFilter
        ? '当前显示 $filteredCount / $totalCount 位学生'
        : '共 $totalCount 位学生';

    return GlassCard(
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
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        unawaited(InteractionFeedback.selection(context));
                        context.push('/students/create');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('新增学生'),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        unawaited(InteractionFeedback.selection(context));
                        context.push('/students/import');
                      },
                      icon: const Icon(Icons.upload_file_outlined),
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
              _StudentSummaryPill(label: '休学 $suspendedCount', color: kOrange),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '查找学生',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kInkSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索姓名、家长姓名或电话',
              helperText: '支持姓名、家长姓名、手机号关键词',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      onPressed: () {
                        unawaited(InteractionFeedback.selection(context));
                        onClearQuery();
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<StudentListFilter>(
              segments: const [
                ButtonSegment(
                  value: StudentListFilter.all,
                  icon: Icon(Icons.grid_view_rounded, size: 18),
                  label: Text('全部'),
                ),
                ButtonSegment(
                  value: StudentListFilter.active,
                  icon: Icon(Icons.verified_user_outlined, size: 18),
                  label: Text('在读'),
                ),
                ButtonSegment(
                  value: StudentListFilter.suspended,
                  icon: Icon(Icons.pause_circle_outline, size: 18),
                  label: Text('休学'),
                ),
              ],
              selected: {query.filter},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                unawaited(InteractionFeedback.selection(context));
                onFilterChanged(selection.first);
              },
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final summaryLine = Semantics(
                  container: true,
                  liveRegion: true,
                  label: resultSummary,
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Icon(
                          query.hasActiveFilter
                              ? Icons.filter_alt_outlined
                              : Icons.people_outline,
                          size: 18,
                          color: kPrimaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            resultSummary,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: kPrimaryBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                final resetButton = TextButton(
                  onPressed: () {
                    unawaited(InteractionFeedback.selection(context));
                    onResetFilters();
                  },
                  style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
                  child: const Text('重置筛选'),
                );

                if (!query.hasActiveFilter) return summaryLine;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summaryLine,
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: resetButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: summaryLine),
                    const SizedBox(width: 8),
                    resetButton,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
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
    final displayName = displayNames[student.id] ?? student.name;
    final parentLine = [
      if (student.parentName?.isNotEmpty ?? false) student.parentName!,
      if (student.parentPhone?.isNotEmpty ?? false) student.parentPhone!,
    ].join(' · ');

    return RepaintBoundary(
      child: GlassCard(
        semanticLabel: '$displayName，${isSuspended ? '休学' : '在读'}，轻触查看学生档案',
        onTap: () {
          unawaited(InteractionFeedback.pageTurn(context));
          context.push('/students/${student.id}');
        },
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 380;
                final avatar = Container(
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
                );
                final identity = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (parentLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        parentLine,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                );
                final statusBadge = _StudentStatusBadge(
                  label: isSuspended ? '休学' : '在读',
                  color: accentColor,
                );
                final editButton = Tooltip(
                  message: '编辑$displayName',
                  child: IconButton.filledTonal(
                    onPressed: () {
                      unawaited(InteractionFeedback.selection(context));
                      context.push('/students/${student.id}/edit');
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: accentColor,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          avatar,
                          const SizedBox(width: 12),
                          Expanded(child: identity),
                          const SizedBox(width: 8),
                          editButton,
                        ],
                      ),
                      const SizedBox(height: 10),
                      statusBadge,
                    ],
                  );
                }

                return Row(
                  children: [
                    avatar,
                    const SizedBox(width: 14),
                    Expanded(child: identity),
                    statusBadge,
                    const SizedBox(width: 8),
                    editButton,
                  ],
                );
              },
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
              child: LayoutBuilder(
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
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: () async {
                            await InteractionFeedback.selection(context);
                            if (!context.mounted) return;
                            await showStudentPaymentSheet(
                              context,
                              studentId: student.id,
                              studentName: displayName,
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
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: () {
                            unawaited(InteractionFeedback.pageTurn(context));
                            context.push('/students/${student.id}');
                          },
                          icon: const Icon(Icons.article_outlined, size: 18),
                          label: const Text('查看档案'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StudentStatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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

class _StudentInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StudentInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 104;
        final maxLabelWidth = (availableWidth - 48)
            .clamp(0.0, double.infinity)
            .toDouble();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: kInkSecondary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxLabelWidth),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
