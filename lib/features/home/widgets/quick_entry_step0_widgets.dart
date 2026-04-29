import 'package:flutter/material.dart';

import '../../../core/database/dao/student_dao.dart';
import '../../../shared/theme.dart';
import 'quick_entry_common_widgets.dart';

class QuickEntryStudentFilterBar extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool allFilteredSelected;
  final VoidCallback? onToggleAllFiltered;
  final bool showSuspended;
  final VoidCallback onToggleShowSuspended;
  final int restorableRecentCount;
  final bool restoredRecentGroup;
  final VoidCallback? onRestoreRecentGroup;
  final int selectedCount;

  const QuickEntryStudentFilterBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.allFilteredSelected,
    required this.onToggleAllFiltered,
    required this.showSuspended,
    required this.onToggleShowSuspended,
    required this.restorableRecentCount,
    required this.restoredRecentGroup,
    required this.onRestoreRecentGroup,
    required this.selectedCount,
  });

  @override
  State<QuickEntryStudentFilterBar> createState() =>
      _QuickEntryStudentFilterBarState();
}

class _QuickEntryStudentFilterBarState
    extends State<QuickEntryStudentFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant QuickEntryStudentFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery == _searchController.text) return;
    _searchController.value = TextEditingValue(
      text: widget.searchQuery,
      selection: TextSelection.collapsed(offset: widget.searchQuery.length),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onClearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索学生姓名或手机号',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasSearchQuery
                  ? IconButton(
                      tooltip: '\u6e05\u7a7a\u641c\u7d22',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.56),
            ),
            onChanged: (value) => widget.onSearchChanged(value.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              QuickActionChip(
                icon: widget.allFilteredSelected
                    ? Icons.deselect
                    : Icons.select_all,
                label: widget.allFilteredSelected ? '取消全选' : '全选',
                onTap: widget.onToggleAllFiltered,
              ),
              QuickActionChip(
                icon: widget.showSuspended
                    ? Icons.visibility_off
                    : Icons.visibility,
                label: widget.showSuspended ? '隐藏休学' : '显示休学',
                onTap: widget.onToggleShowSuspended,
              ),
              if (widget.restorableRecentCount > 0)
                QuickActionChip(
                  icon: widget.restoredRecentGroup
                      ? Icons.checklist_rtl_outlined
                      : Icons.history_outlined,
                  label: widget.restoredRecentGroup
                      ? '上次同班已恢复'
                      : '恢复上次同班（${widget.restorableRecentCount}人）',
                  onTap: widget.onRestoreRecentGroup,
                ),
              _QuickEntrySelectedCountPill(selectedCount: widget.selectedCount),
            ],
          ),
        ),
      ],
    );
  }
}

class QuickEntryStudentEmptyState extends StatelessWidget {
  final String message;
  final bool showStudentActions;
  final VoidCallback onImportStudents;
  final VoidCallback onCreateStudent;

  const QuickEntryStudentEmptyState({
    super.key,
    required this.message,
    required this.showStudentActions,
    required this.onImportStudents,
    required this.onCreateStudent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              if (showStudentActions) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 340;
                    final importButton = OutlinedButton.icon(
                      onPressed: onImportStudents,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('批量导入'),
                    );
                    final createButton = FilledButton.icon(
                      onPressed: onCreateStudent,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('新增学生'),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          importButton,
                          const SizedBox(height: 10),
                          createButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: importButton),
                        const SizedBox(width: 12),
                        Expanded(child: createButton),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class QuickEntryStudentList extends StatelessWidget {
  final ScrollController controller;
  final List<StudentWithMeta> students;
  final Set<String> selectedIds;
  final Map<String, String> displayNames;
  final void Function(StudentWithMeta student, bool selected) onToggleStudent;

  const QuickEntryStudentList({
    super.key,
    required this.controller,
    required this.students,
    required this.selectedIds,
    required this.displayNames,
    required this.onToggleStudent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: students.length,
      itemBuilder: (_, index) {
        final studentWithMeta = students[index];
        final selected = selectedIds.contains(studentWithMeta.student.id);
        final displayName =
            displayNames[studentWithMeta.student.id] ??
            studentWithMeta.student.name;

        void toggleSelection([bool? value]) {
          final shouldSelect = value ?? !selected;
          onToggleStudent(studentWithMeta, shouldSelect);
        }

        return _QuickEntryStudentListItem(
          studentWithMeta: studentWithMeta,
          displayName: displayName,
          selected: selected,
          isLastItem: index == students.length - 1,
          onToggle: toggleSelection,
        );
      },
    );
  }
}

class QuickEntryStep0Actions extends StatelessWidget {
  final bool canContinue;
  final int selectedCount;
  final int quickSaveStudentCount;
  final String estimatedFeeLabel;
  final VoidCallback onContinue;
  final VoidCallback onQuickSave;

  const QuickEntryStep0Actions({
    super.key,
    required this.canContinue,
    required this.selectedCount,
    required this.quickSaveStudentCount,
    required this.estimatedFeeLabel,
    required this.onContinue,
    required this.onQuickSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canContinue ? onContinue : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text('下一步（已选 $selectedCount 人）'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canContinue ? onQuickSave : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.flash_on_outlined),
              label: Text(
                '保存默认（$quickSaveStudentCount人 / ¥$estimatedFeeLabel）',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickEntrySelectedCountPill extends StatelessWidget {
  final int selectedCount;

  const _QuickEntrySelectedCountPill({required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '已选 $selectedCount',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: kPrimaryBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuickEntryStudentListItem extends StatelessWidget {
  final StudentWithMeta studentWithMeta;
  final String displayName;
  final bool selected;
  final bool isLastItem;
  final ValueChanged<bool?> onToggle;

  const _QuickEntryStudentListItem({
    required this.studentWithMeta,
    required this.displayName,
    required this.selected,
    required this.isLastItem,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = studentWithMeta.student.status == 'active' ? '在读' : '休学';
    final statusColor = studentWithMeta.student.status == 'active'
        ? kGreen
        : kOrange;

    return Semantics(
      button: true,
      selected: selected,
      label: '$displayName，$statusText，${selected ? '已选择' : '未选择'}，轻触切换选择',
      onTap: () => onToggle(null),
      child: ExcludeSemantics(
        child: Container(
          margin: EdgeInsets.only(bottom: isLastItem ? 0 : 10),
          decoration: BoxDecoration(
            color: selected
                ? kPrimaryBlue.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? kPrimaryBlue.withValues(alpha: 0.28)
                  : kInkSecondary.withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onToggle(null),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Checkbox(value: selected, onChanged: onToggle),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (studentWithMeta.student.parentPhone?.isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 4),
                          Text(
                            studentWithMeta.student.parentPhone!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            QuickInfoPill(
                              icon: Icons.payments_outlined,
                              label:
                                  '¥${studentWithMeta.student.pricePerClass.toStringAsFixed(0)}/节',
                            ),
                            QuickInfoPill(
                              icon: Icons.badge_outlined,
                              label: statusText,
                              color: statusColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
