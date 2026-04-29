import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/dao/student_dao.dart';
import '../../../core/models/structured_attendance_feedback.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/class_template_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/time_wheel_picker.dart';
import 'quick_entry_conflict_dialog.dart';
import 'quick_entry_sheet_components.dart';
import '../services/quick_entry_record_builder.dart';

const quickEntryDefaultStartTimeSettingKey = 'quick_entry_default_start_time';
const quickEntryDefaultEndTimeSettingKey = 'quick_entry_default_end_time';
const quickEntryDefaultStatusSettingKey = 'quick_entry_default_status';
const quickEntryRecentStudentIdsSettingKey = 'quick_entry_recent_student_ids';

const quickEntryStatuses = <(String, String)>[
  ('present', '出勤'),
  ('late', '迟到'),
  ('leave', '请假'),
  ('absent', '缺勤'),
  ('trial', '试听'),
];

bool isQuickEntryValidTimeValue(String? value) {
  if (value == null) return false;
  final segments = value.split(':');
  if (segments.length != 2) return false;
  final hour = int.tryParse(segments[0]);
  final minute = int.tryParse(segments[1]);
  if (hour == null || minute == null) return false;
  return hour >= 0 && hour < 24 && minute >= 0 && minute < 60;
}

Set<String> parseQuickEntryRecentStudentIds(Map<String, String> settings) {
  final raw = settings[quickEntryRecentStudentIdsSettingKey]?.trim();
  if (raw == null || raw.isEmpty) return const <String>{};
  return raw
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
}

String quickEntryStatusLabel(String? status) {
  for (final item in quickEntryStatuses) {
    if (item.$1 == status) return item.$2;
  }
  return status ?? '';
}

class QuickEntrySheet extends ConsumerStatefulWidget {
  final Set<String> initialSelectedIds;
  final String? initialStartTime;
  final String? initialEndTime;
  final String? initialStatus;

  const QuickEntrySheet({
    super.key,
    this.initialSelectedIds = const <String>{},
    this.initialStartTime,
    this.initialEndTime,
    this.initialStatus,
  });

  @override
  ConsumerState<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<QuickEntrySheet> {
  int _step = 0;
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  String _status = 'present';
  String _startTime = '09:00';
  String _endTime = '10:00';
  late DateTime _date;
  final Set<String> _lessonFocusTags = <String>{};
  late final TextEditingController _homePracticeCtrl;
  double? _strokeQuality;
  double? _structureAccuracy;
  double? _rhythmConsistency;
  bool _saving = false;
  bool _showSuspended = false;
  bool _loadedRememberedDefaults = false;
  bool _customizedDefaults = false;
  late final ProviderSubscription<AsyncValue<Map<String, String>>>
  _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _date = ref.read(selectedDateProvider);
    _homePracticeCtrl = TextEditingController();
    _selectedIds.addAll(widget.initialSelectedIds);
    var hasExplicitPreset = false;
    if (isQuickEntryValidTimeValue(widget.initialStartTime)) {
      _startTime = widget.initialStartTime!;
      hasExplicitPreset = true;
    }
    if (isQuickEntryValidTimeValue(widget.initialEndTime)) {
      _endTime = widget.initialEndTime!;
      hasExplicitPreset = true;
    }
    if (quickEntryStatuses.any((item) => item.$1 == widget.initialStatus)) {
      _status = widget.initialStatus!;
      hasExplicitPreset = true;
    }
    _customizedDefaults = hasExplicitPreset;
    _settingsSubscription = ref.listenManual(settingsProvider, (
      previous,
      next,
    ) {
      _maybeRestoreRememberedDefaults(next.valueOrNull);
    });
    _maybeRestoreRememberedDefaults(ref.read(settingsProvider).valueOrNull);
  }

  @override
  void dispose() {
    _settingsSubscription.close();
    _homePracticeCtrl.dispose();
    super.dispose();
  }

  Future<void> _openStudentRoute(String route) async {
    await InteractionFeedback.pageTurn(context);
    if (!mounted) return;
    final router = GoRouter.of(context);
    await Navigator.of(context).maybePop();
    router.push(route);
  }

  String _dateStr() => formatDate(_date);

  bool _restoreRememberedDefaults(Map<String, String> settings) {
    final savedStartTime = settings[quickEntryDefaultStartTimeSettingKey]
        ?.trim();
    final savedEndTime = settings[quickEntryDefaultEndTimeSettingKey]?.trim();
    final savedStatus = settings[quickEntryDefaultStatusSettingKey]?.trim();
    var restored = false;

    if (isQuickEntryValidTimeValue(savedStartTime)) {
      _startTime = savedStartTime!;
      restored = true;
    }
    if (isQuickEntryValidTimeValue(savedEndTime)) {
      _endTime = savedEndTime!;
      restored = true;
    }
    if (quickEntryStatuses.any((item) => item.$1 == savedStatus)) {
      _status = savedStatus!;
      restored = true;
    }

    return restored;
  }

  void _maybeRestoreRememberedDefaults(Map<String, String>? settings) {
    if (settings == null || _customizedDefaults || _loadedRememberedDefaults) {
      return;
    }
    final restored = _restoreRememberedDefaults(settings);
    if (!restored || !mounted) return;
    setState(() => _loadedRememberedDefaults = true);
  }

  void _markDefaultsCustomized() {
    _customizedDefaults = true;
    _loadedRememberedDefaults = false;
  }

  Set<String> _recentStudentIds(Map<String, String> settings) {
    return parseQuickEntryRecentStudentIds(settings);
  }

  Future<void> _persistQuickEntryPreferences(
    List<StudentWithMeta> selectedStudents,
  ) async {
    await ref.read(settingsProvider.notifier).setAll({
      quickEntryDefaultStartTimeSettingKey: _startTime,
      quickEntryDefaultEndTimeSettingKey: _endTime,
      quickEntryDefaultStatusSettingKey: _status,
      quickEntryRecentStudentIdsSettingKey: selectedStudents
          .map((item) => item.student.id)
          .join(','),
    });
  }

  AttendanceProgressScores? _buildProgressScores() {
    if (_strokeQuality == null &&
        _structureAccuracy == null &&
        _rhythmConsistency == null) {
      return null;
    }
    return AttendanceProgressScores(
      strokeQuality: _strokeQuality,
      structureAccuracy: _structureAccuracy,
      rhythmConsistency: _rhythmConsistency,
    );
  }

  List<StudentWithMeta> _selectedStudentsFrom(List<StudentWithMeta> students) {
    return students
        .where((item) => _selectedIds.contains(item.student.id))
        .toList(growable: false);
  }

  List<String> _studentNamesFrom(
    List<StudentWithMeta> students,
    Map<String, String> displayNames,
  ) {
    return students
        .map((item) => displayNames[item.student.id] ?? item.student.name)
        .toList(growable: false);
  }

  String _studentNamePreview(List<String> names, {int limit = 8}) {
    if (names.length <= limit) return names.join('、');
    return '${names.take(limit).join('、')} 等 ${names.length} 人';
  }

  double _estimatedTotalFee(List<StudentWithMeta> selectedStudents) {
    final statusEnum = AttendanceStatus.values.firstWhere(
      (item) => item.name == _status,
    );
    return selectedStudents.fold<double>(
      0,
      (sum, item) =>
          sum + FeeCalculator.calcFee(statusEnum, item.student.pricePerClass),
    );
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    setState(() => _date = d);
  }

  Future<void> _pickStartTime() async {
    final t = await showTimeWheelPicker(
      context: context,
      initialTime: parseTime(_startTime),
      label: '开始时间',
    );
    if (t == null || !mounted) return;
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    setState(() {
      _markDefaultsCustomized();
      _startTime = formatTime(t);
    });
  }

  Future<void> _pickEndTime() async {
    final t = await showTimeWheelPicker(
      context: context,
      initialTime: parseTime(_endTime),
      label: '结束时间',
    );
    if (t == null || !mounted) return;
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    setState(() {
      _markDefaultsCustomized();
      _endTime = formatTime(t);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_endTime.compareTo(_startTime) <= 0) {
      AppToast.showError(context, '结束时间必须晚于开始时间');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final dao = ref.read(attendanceDaoProvider);
      final students = ref.read(studentProvider).valueOrNull ?? [];
      final existingIds = students.map((m) => m.student.id).toSet();
      // Remove IDs for students that no longer exist
      _selectedIds.retainAll(existingIds);
      if (_selectedIds.isEmpty) {
        if (mounted) AppToast.showError(context, '没有可保存的学生');
        return;
      }
      final selectedStudents = students
          .where((m) => _selectedIds.contains(m.student.id))
          .toList();
      final displayNames = ref.read(studentDisplayNameMapProvider);
      final conflictRecords = await dao.findConflictsForStudents(
        selectedStudents.map((m) => m.student.id),
        _dateStr(),
        _startTime,
        _endTime,
      );
      final conflictItems = [
        for (final item in selectedStudents)
          if (conflictRecords.containsKey(item.student.id))
            QuickEntryConflictItem(
              studentName: displayNames[item.student.id] ?? item.student.name,
              existingTimeRange:
                  '${conflictRecords[item.student.id]!.startTime}-${conflictRecords[item.student.id]!.endTime}',
              existingStatusLabel: quickEntryStatusLabel(
                conflictRecords[item.student.id]!.status,
              ),
            ),
      ];

      if (conflictItems.isNotEmpty && mounted) {
        final resolution = await showQuickEntryConflictDialog(
          context: context,
          currentSlot: '${_dateStr()} $_startTime-$_endTime',
          conflicts: conflictItems,
        );
        if (resolution != QuickEntryConflictResolution.overwrite) {
          if (resolution == QuickEntryConflictResolution.changeTime &&
              mounted) {
            setState(() => _step = 1);
            AppToast.showSuccess(context, '已返回时间设置，可调整后重新保存');
          }
          return;
        }
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final lessonFocusTags = _lessonFocusTags.toList(growable: false);
      final homePracticeNote = _homePracticeCtrl.text.trim();
      final progressScores = _buildProgressScores();

      final buildResult = const QuickEntryRecordBuilder().build(
        request: QuickEntryRecordRequest(
          students: selectedStudents
              .map((item) => item.student)
              .toList(growable: false),
          conflictRecordsByStudentId: conflictRecords,
          date: _dateStr(),
          startTime: _startTime,
          endTime: _endTime,
          status: _status,
          lessonFocusTags: lessonFocusTags,
          homePracticeNote: homePracticeNote,
          progressScores: progressScores,
          nowMs: now,
          idFactory: () => const Uuid().v4(),
        ),
      );

      await _persistQuickEntryPreferences(selectedStudents);
      await dao.batchInsertWithConflictReplace(
        buildResult.records,
        buildResult.conflictIds,
      );

      invalidateAfterAttendanceChange(ref);

      if (!mounted) return;
      await InteractionFeedback.seal(context);
      if (!mounted) return;
      AppToast.showSuccess(context, '已保存 ${selectedStudents.length} 条出勤记录');
      Navigator.of(context).pop();
    } on QuickEntryInvalidPriceException catch (error) {
      final displayName =
          ref.read(studentDisplayNameMapProvider)[error.student.id] ??
          error.student.name;
      if (mounted) {
        AppToast.showError(context, '$displayName 的课时单价无效，请先编辑学生档案。');
      }
    } on FormatException catch (error) {
      if (mounted) {
        AppToast.showError(
          context,
          error.message.isEmpty ? '出勤记录格式无效，请检查学生档案和记课设置。' : error.message,
        );
      }
    } catch (error) {
      if (mounted) AppToast.showError(context, '保存出勤记录失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _quickSaveWithDefaults() async {
    if (_saving || _selectedIds.isEmpty) return;
    if (_endTime.compareTo(_startTime) <= 0) {
      AppToast.showError(context, '结束时间必须晚于开始时间');
      return;
    }
    final students = ref.read(studentProvider).valueOrNull ?? const [];
    final selectedStudents = _selectedStudentsFrom(students);
    if (selectedStudents.isEmpty) {
      AppToast.showError(context, '没有可保存的学生');
      return;
    }
    final totalFee = _estimatedTotalFee(selectedStudents);
    final statusLabel = quickEntryStatusLabel(_status);
    final selectedNames = _studentNamesFrom(
      selectedStudents,
      ref.read(studentDisplayNameMapProvider),
    );
    final confirmed = await AppToast.showConfirm(
      context,
      '按默认记课：${_dateStr()} $_startTime-$_endTime · $statusLabel · ${selectedStudents.length}人 · ¥${_formatAmount(totalFee)}\n${_studentNamePreview(selectedNames)}',
    );
    if (!confirmed) return;
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding =
        mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 12;
    final horizontalPadding = mediaQuery.size.width < 380 ? 10.0 : 16.0;
    final stepIndicatorDuration = mediaQuery.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          8,
          horizontalPadding,
          bottomPadding,
        ),
        child: GlassCard(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kInkSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Column(
                  children: [
                    Text(
                      ['选择学员', '确认并保存'][_step],
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ['选择本次学员。', '确认时间与状态。'][_step],
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    2,
                    (i) => AnimatedContainer(
                      duration: stepIndicatorDuration,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _step == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _step >= i
                            ? theme.colorScheme.primary
                            : theme.dividerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _step == 0 ? _buildStep0(controller) : _buildStep1(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0(ScrollController controller) {
    final studentsAsync = ref.watch(studentProvider);
    final students = studentsAsync.valueOrNull ?? const <StudentWithMeta>[];
    final studentsLoading = studentsAsync.isLoading && students.isEmpty;
    final studentsLoadFailed = studentsAsync.hasError && students.isEmpty;
    final settings = ref.watch(settingsProvider).valueOrNull ?? const {};
    final activeStudents = _showSuspended
        ? students
        : students.where((m) => m.student.status == 'active').toList();
    final filtered = _searchQuery.isEmpty
        ? activeStudents
        : activeStudents.where((m) {
            return m.student.name.contains(_searchQuery) ||
                (m.student.parentPhone?.contains(_searchQuery) ?? false);
          }).toList();

    final displayNames = ref.watch(studentDisplayNameMapProvider);
    final filteredIds = filtered.map((m) => m.student.id).toSet();
    final allFilteredSelected =
        filteredIds.isNotEmpty &&
        filteredIds.every((id) => _selectedIds.contains(id));
    final restorableStudents = _showSuspended ? students : activeStudents;
    final restorableRecentIds = _recentStudentIds(
      settings,
    ).intersection(restorableStudents.map((item) => item.student.id).toSet());
    final restoredRecentGroup =
        restorableRecentIds.isNotEmpty &&
        restorableRecentIds.every((id) => _selectedIds.contains(id));
    final selectedStudents = _selectedStudentsFrom(students);
    final estimatedTotalFee = _estimatedTotalFee(selectedStudents);
    final estimatedTotalFeeLabel = _formatAmount(estimatedTotalFee);
    final canContinue =
        !studentsLoading && !studentsLoadFailed && selectedStudents.isNotEmpty;
    final emptyMessage = students.isEmpty
        ? '先新增或导入学生。'
        : _searchQuery.isEmpty
        ? '没有可记课学员。'
        : '没有匹配学员。';
    final showStudentActions = students.isEmpty || _searchQuery.isEmpty;

    return Column(
      children: [
        QuickEntryStudentFilterBar(
          searchQuery: _searchQuery,
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          onClearSearch: () {
            if (_searchQuery.isEmpty) return;
            setState(() => _searchQuery = '');
          },
          allFilteredSelected: allFilteredSelected,
          onToggleAllFiltered: filtered.isEmpty
              ? null
              : () {
                  unawaited(InteractionFeedback.selection(context));
                  setState(() {
                    if (allFilteredSelected) {
                      _selectedIds.removeAll(filteredIds);
                    } else {
                      _selectedIds.addAll(filteredIds);
                    }
                  });
                },
          showSuspended: _showSuspended,
          onToggleShowSuspended: () {
            unawaited(InteractionFeedback.selection(context));
            setState(() => _showSuspended = !_showSuspended);
          },
          restorableRecentCount: restorableRecentIds.length,
          restoredRecentGroup: restoredRecentGroup,
          onRestoreRecentGroup: restoredRecentGroup
              ? null
              : () {
                  unawaited(InteractionFeedback.selection(context));
                  setState(() {
                    _selectedIds.addAll(restorableRecentIds);
                  });
                },
          selectedCount: _selectedIds.length,
        ),
        if (_loadedRememberedDefaults)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.12)),
              ),
              child: Text(
                '默认：$_startTime-$_endTime / ${quickEntryStatusLabel(_status)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kPrimaryBlue,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: studentsLoading
              ? const QuickEntryStudentLoading()
              : studentsLoadFailed
              ? QuickEntryStudentLoadError(
                  onRetry: () => ref.invalidate(studentProvider),
                )
              : filtered.isEmpty
              ? QuickEntryStudentEmptyState(
                  message: emptyMessage,
                  showStudentActions: showStudentActions,
                  onImportStudents: () => _openStudentRoute('/students/import'),
                  onCreateStudent: () => _openStudentRoute('/students/create'),
                )
              : QuickEntryStudentList(
                  controller: controller,
                  students: filtered,
                  selectedIds: _selectedIds,
                  displayNames: displayNames,
                  onToggleStudent: (studentWithMeta, shouldSelect) {
                    unawaited(InteractionFeedback.selection(context));
                    setState(() {
                      if (shouldSelect) {
                        _selectedIds.add(studentWithMeta.student.id);
                      } else {
                        _selectedIds.remove(studentWithMeta.student.id);
                      }
                    });
                  },
                ),
        ),
        QuickEntryStep0Actions(
          canContinue: canContinue,
          selectedCount: _selectedIds.length,
          quickSaveStudentCount: selectedStudents.length,
          estimatedFeeLabel: estimatedTotalFeeLabel,
          onContinue: () {
            unawaited(InteractionFeedback.selection(context));
            setState(() => _step = 1);
          },
          onQuickSave: () {
            unawaited(InteractionFeedback.selection(context));
            unawaited(_quickSaveWithDefaults());
          },
        ),
      ],
    );
  }

  Widget _buildStep1() {
    final theme = Theme.of(context);
    final templates = ref.watch(classTemplateProvider).valueOrNull ?? [];
    final students = ref.watch(studentProvider).valueOrNull ?? const [];
    final displayNames = ref.watch(studentDisplayNameMapProvider);
    final selectedStudents = _selectedStudentsFrom(students);
    final selectedNames = _studentNamesFrom(selectedStudents, displayNames);
    final estimatedTotalFeeLabel = _formatAmount(
      _estimatedTotalFee(selectedStudents),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loadedRememberedDefaults) ...[
          QuickEntryRememberedDefaultsBanner(
            startTime: _startTime,
            endTime: _endTime,
            statusLabel: quickEntryStatusLabel(_status),
          ),
          const SizedBox(height: 16),
        ],
        if (selectedNames.isNotEmpty) ...[
          QuickEntrySelectedStudentsSection(selectedNames: selectedNames),
          const SizedBox(height: 16),
        ],
        if (templates.isNotEmpty) ...[
          Text('常用模板', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: templates
                .map(
                  (t) => ActionChip(
                    label: Text('${t.name} ${t.startTime}-${t.endTime}'),
                    backgroundColor: Colors.white.withValues(alpha: 0.56),
                    side: BorderSide(
                      color: kInkSecondary.withValues(alpha: 0.14),
                    ),
                    onPressed: () {
                      unawaited(InteractionFeedback.selection(context));
                      setState(() {
                        _markDefaultsCustomized();
                        _startTime = t.startTime;
                        _endTime = t.endTime;
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        QuickEntryPickerField(
          label: '上课日期',
          semanticsLabel: '上课日期选择器',
          semanticsHint: '轻触选择上课日期',
          value: _dateStr(),
          trailingIcon: Icons.calendar_today_outlined,
          onTap: _pickDate,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 340;
            final startPicker = QuickEntryPickerField(
              label: '开始时间',
              semanticsLabel: '开始时间选择器',
              semanticsHint: '轻触选择开始时间',
              value: _startTime,
              onTap: _pickStartTime,
            );
            final endPicker = QuickEntryPickerField(
              label: '结束时间',
              semanticsLabel: '结束时间选择器',
              semanticsHint: '轻触选择结束时间',
              value: _endTime,
              onTap: _pickEndTime,
            );

            if (compact) {
              return Column(
                children: [startPicker, const SizedBox(height: 12), endPicker],
              );
            }

            return Row(
              children: [
                Expanded(child: startPicker),
                const SizedBox(width: 12),
                Expanded(child: endPicker),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text('出勤状态', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickEntryStatuses
              .map(
                (s) => ChoiceChip(
                  label: Text(s.$2),
                  selected: _status == s.$1,
                  onSelected: (_) {
                    unawaited(InteractionFeedback.selection(context));
                    setState(() {
                      _markDefaultsCustomized();
                      _status = s.$1;
                    });
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        QuickEntryFeedbackSection(
          selectedLessonFocusTags: _lessonFocusTags,
          homePracticeController: _homePracticeCtrl,
          strokeQuality: _strokeQuality,
          structureAccuracy: _structureAccuracy,
          rhythmConsistency: _rhythmConsistency,
          onLessonFocusTagSelected: (tag, selected) {
            setState(() {
              if (selected) {
                _lessonFocusTags.add(tag);
              } else {
                _lessonFocusTags.remove(tag);
              }
            });
          },
          onStrokeQualityChanged: (value) =>
              setState(() => _strokeQuality = value),
          onStrokeQualityCleared: () => setState(() => _strokeQuality = null),
          onStructureAccuracyChanged: (value) =>
              setState(() => _structureAccuracy = value),
          onStructureAccuracyCleared: () =>
              setState(() => _structureAccuracy = null),
          onRhythmConsistencyChanged: (value) =>
              setState(() => _rhythmConsistency = value),
          onRhythmConsistencyCleared: () =>
              setState(() => _rhythmConsistency = null),
        ),
        const SizedBox(height: 16),
        QuickEntrySelectionSummaryPanel(
          dateLabel: _dateStr(),
          timeRangeLabel: '$_startTime - $_endTime',
          statusLabel: quickEntryStatusLabel(_status),
          statusColor: statusColor(_status),
          selectedCount: _selectedIds.length,
          estimatedFeeLabel: '\u9884\u8ba1 \u00a5$estimatedTotalFeeLabel',
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 340;
            final backButton = OutlinedButton(
              onPressed: () {
                unawaited(InteractionFeedback.selection(context));
                setState(() => _step = 0);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('上一步'),
            );
            final saveButton = ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_saving ? '保存中...' : '确认保存'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [saveButton, const SizedBox(height: 10), backButton],
              );
            }

            return Row(
              children: [
                Expanded(child: backButton),
                const SizedBox(width: 12),
                Expanded(child: saveButton),
              ],
            );
          },
        ),
      ],
    );
  }
}
