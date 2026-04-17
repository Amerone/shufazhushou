import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/dao/student_dao.dart';
import '../../../core/models/attendance.dart';
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
    Navigator.of(context).pop();
    if (!mounted) return;
    context.push(route);
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
      final invalidPriceStudent = selectedStudents
          .where((m) => m.student.pricePerClass < 0)
          .firstOrNull;
      if (invalidPriceStudent != null) {
        final displayName =
            ref.read(
              studentDisplayNameMapProvider,
            )[invalidPriceStudent.student.id] ??
            invalidPriceStudent.student.name;
        if (mounted) {
          AppToast.showError(context, '$displayName 的课时单价无效，请先编辑学生档案。');
        }
        return;
      }

      final displayNames = ref.read(studentDisplayNameMapProvider);
      final conflictRecords = await dao.findConflictsForStudents(
        selectedStudents.map((m) => m.student.id),
        _dateStr(),
        _startTime,
        _endTime,
      );
      final conflictIds = {
        for (final entry in conflictRecords.entries) entry.key: entry.value.id,
      };
      final conflicts = [
        for (final m in selectedStudents)
          if (conflictRecords.containsKey(m.student.id))
            (displayNames[m.student.id] ?? m.student.name),
      ];

      if (conflicts.isNotEmpty && mounted) {
        final ok = await AppToast.showConfirm(
          context,
          '以下学生该时段已有记录：${conflicts.join('、')}，是否覆盖？',
        );
        if (!ok) return;
      }

      final statusEnum = AttendanceStatus.values.firstWhere(
        (e) => e.name == _status,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final lessonFocusTags = _lessonFocusTags.toList(growable: false);
      final homePracticeNote = _homePracticeCtrl.text.trim();
      final progressScores = _buildProgressScores();

      final records = <Attendance>[];
      for (final m in selectedStudents) {
        final price = m.student.pricePerClass;
        final fee = FeeCalculator.calcFee(statusEnum, price);
        final existingRecord = conflictRecords[m.student.id];
        final resolvedLessonFocusTags =
            existingRecord != null && lessonFocusTags.isEmpty
            ? existingRecord.lessonFocusTags
            : lessonFocusTags;
        final resolvedHomePracticeNote =
            existingRecord != null && homePracticeNote.isEmpty
            ? existingRecord.homePracticeNote
            : (homePracticeNote.isEmpty ? null : homePracticeNote);
        final resolvedProgressScores =
            existingRecord != null && progressScores == null
            ? existingRecord.progressScores
            : progressScores;

        records.add(
          existingRecord?.copyWith(
                date: _dateStr(),
                startTime: _startTime,
                endTime: _endTime,
                status: _status,
                priceSnapshot: price,
                feeAmount: fee,
                lessonFocusTags: resolvedLessonFocusTags,
                homePracticeNote: resolvedHomePracticeNote,
                progressScores: resolvedProgressScores,
                updatedAt: now,
              ) ??
              Attendance(
                id: const Uuid().v4(),
                studentId: m.student.id,
                date: _dateStr(),
                startTime: _startTime,
                endTime: _endTime,
                status: _status,
                priceSnapshot: price,
                feeAmount: fee,
                lessonFocusTags: resolvedLessonFocusTags,
                homePracticeNote: resolvedHomePracticeNote,
                progressScores: resolvedProgressScores,
                createdAt: now,
                updatedAt: now,
              ),
        );
      }

      await _persistQuickEntryPreferences(selectedStudents);
      await dao.batchInsertWithConflictReplace(records, conflictIds);

      invalidateAfterAttendanceChange(ref);

      if (!mounted) return;
      await InteractionFeedback.seal(context);
      if (!mounted) return;
      AppToast.showSuccess(context, '已保存 ${selectedStudents.length} 条出勤记录');
      Navigator.of(context).pop();
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
    final students = ref.read(studentProvider).valueOrNull ?? const [];
    final selectedStudents = _selectedStudentsFrom(students);
    final totalFee = _estimatedTotalFee(selectedStudents);
    final statusLabel = quickEntryStatusLabel(_status);
    final confirmed = await AppToast.showConfirm(
      context,
      '将直接记课：${_dateStr()} $_startTime-$_endTime，状态“$statusLabel”，共 ${selectedStudents.length} 人，预计扣费 ¥${_formatAmount(totalFee)}。是否继续？',
    );
    if (!confirmed) return;
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom + 12;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
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
                      ['搜索并批量勾选本次需要记课的学员。', '设置日期、时间和出勤状态，确认后直接保存。'][_step],
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
                      duration: const Duration(milliseconds: 180),
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
              Expanded(child: [_buildStep0(controller), _buildStep1()][_step]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0(ScrollController controller) {
    final students = ref.watch(studentProvider).valueOrNull ?? [];
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索学生姓名或手机号',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.56),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _QuickActionChip(
                icon: allFilteredSelected ? Icons.deselect : Icons.select_all,
                label: allFilteredSelected ? '取消全选' : '全选',
                onTap: filtered.isEmpty
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
              ),
              _QuickActionChip(
                icon: _showSuspended ? Icons.visibility_off : Icons.visibility,
                label: _showSuspended ? '隐藏休学' : '显示休学',
                onTap: () {
                  unawaited(InteractionFeedback.selection(context));
                  setState(() => _showSuspended = !_showSuspended);
                },
              ),
              if (restorableRecentIds.isNotEmpty)
                _QuickActionChip(
                  icon: restoredRecentGroup
                      ? Icons.checklist_rtl_outlined
                      : Icons.history_outlined,
                  label: restoredRecentGroup
                      ? '上次同班已恢复'
                      : '恢复上次同班（${restorableRecentIds.length}人）',
                  onTap: restoredRecentGroup
                      ? null
                      : () {
                          unawaited(InteractionFeedback.selection(context));
                          setState(() {
                            _selectedIds.addAll(restorableRecentIds);
                          });
                        },
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '已选 ${_selectedIds.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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
                '当前默认：$_startTime-$_endTime / ${quickEntryStatusLabel(_status)}，可直接用“按当前默认直接保存”。',
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
          child: filtered.isEmpty
              ? Padding(
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
                              students.isEmpty
                                  ? '还没有学生档案，先新增或导入学生，之后就能直接记课。'
                                  : _searchQuery.isEmpty
                                  ? '当前没有可记课的学员，可切换“显示休学”或先新增学生。'
                                  : '没有找到符合条件的学员。',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (students.isEmpty || _searchQuery.isEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openStudentRoute('/students/import'),
                                    icon: const Icon(
                                      Icons.upload_file_outlined,
                                    ),
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
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final m = filtered[i];
                    final selected = _selectedIds.contains(m.student.id);
                    final statusText = m.student.status == 'active'
                        ? '在读'
                        : '休学';
                    final statusColorValue = m.student.status == 'active'
                        ? kGreen
                        : kOrange;

                    return Container(
                      margin: EdgeInsets.only(
                        bottom: i == filtered.length - 1 ? 0 : 10,
                      ),
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
                        onTap: () {
                          unawaited(InteractionFeedback.selection(context));
                          setState(() {
                            if (selected) {
                              _selectedIds.remove(m.student.id);
                            } else {
                              _selectedIds.add(m.student.id);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (v) {
                                  unawaited(
                                    InteractionFeedback.selection(context),
                                  );
                                  setState(() {
                                    if (v == true) {
                                      _selectedIds.add(m.student.id);
                                    } else {
                                      _selectedIds.remove(m.student.id);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayNames[m.student.id] ??
                                          m.student.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (m.student.parentPhone?.isNotEmpty ??
                                        false) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        m.student.parentPhone!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _QuickInfoPill(
                                          icon: Icons.payments_outlined,
                                          label:
                                              '¥${m.student.pricePerClass.toStringAsFixed(0)}/节',
                                        ),
                                        _QuickInfoPill(
                                          icon: Icons.badge_outlined,
                                          label: statusText,
                                          color: statusColorValue,
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
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () {
                          unawaited(InteractionFeedback.selection(context));
                          setState(() => _step = 1);
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('下一步（已选 ${_selectedIds.length} 人）'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () {
                          unawaited(InteractionFeedback.selection(context));
                          unawaited(_quickSaveWithDefaults());
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.flash_on_outlined),
                  label: Text(
                    '直接保存（${selectedStudents.length}人 / ¥${_formatAmount(estimatedTotalFee)}）',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '直接保存会按当前日期、时间和状态记课，预计扣费 ¥${_formatAmount(estimatedTotalFee)}。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    final theme = Theme.of(context);
    final templates = ref.watch(classTemplateProvider).valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loadedRememberedDefaults) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.history_toggle_off_outlined,
                    size: 16,
                    color: kPrimaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已沿用上次常用设置：$_startTime-$_endTime，状态“${quickEntryStatusLabel(_status)}”。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: kPrimaryBlue,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
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
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '上课日期',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.56),
            ),
            child: Row(
              children: [
                Expanded(child: Text(_dateStr())),
                const Icon(Icons.calendar_today_outlined, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
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
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '开始时间',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.56),
                  ),
                  child: Text(_startTime),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
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
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '结束时间',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.56),
                  ),
                  child: Text(_endTime),
                ),
              ),
            ),
          ],
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
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.only(top: 4),
            title: Text('课堂反馈（可选）', style: theme.textTheme.titleSmall),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('课堂重点', style: theme.textTheme.bodySmall),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kLessonFocusTagOptions
                    .map(
                      (tag) => FilterChip(
                        label: Text(tag),
                        selected: _lessonFocusTags.contains(tag),
                        onSelected: (selected) {
                          unawaited(InteractionFeedback.selection(context));
                          setState(() {
                            if (selected) {
                              _lessonFocusTags.add(tag);
                            } else {
                              _lessonFocusTags.remove(tag);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _homePracticeCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '课后练习建议',
                  hintText: '例如：每日临摹 15 分钟，重点观察起收笔节奏。',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.56),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('进步评分（0-5）', style: theme.textTheme.bodySmall),
              ),
              const SizedBox(height: 8),
              _ScoreEditor(
                label: '笔画质量',
                value: _strokeQuality,
                onChanged: (value) => setState(() => _strokeQuality = value),
                onClear: () => setState(() => _strokeQuality = null),
              ),
              _ScoreEditor(
                label: '结构准确',
                value: _structureAccuracy,
                onChanged: (value) =>
                    setState(() => _structureAccuracy = value),
                onClear: () => setState(() => _structureAccuracy = null),
              ),
              _ScoreEditor(
                label: '节奏连贯',
                value: _rhythmConsistency,
                onChanged: (value) =>
                    setState(() => _rhythmConsistency = value),
                onClear: () => setState(() => _rhythmConsistency = null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kPrimaryBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.12)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickInfoPill(
                icon: Icons.calendar_today_outlined,
                label: _dateStr(),
              ),
              _QuickInfoPill(
                icon: Icons.access_time_outlined,
                label: '$_startTime - $_endTime',
              ),
              _QuickInfoPill(
                icon: Icons.flag_outlined,
                label: quickEntryStatusLabel(_status),
                color: statusColor(_status),
              ),
              _QuickInfoPill(
                icon: Icons.groups_2_outlined,
                label: '${_selectedIds.length} 人',
              ),
              _QuickInfoPill(
                icon: Icons.payments_outlined,
                label:
                    '预计 ¥${_formatAmount(_estimatedTotalFee(_selectedStudentsFrom(ref.read(studentProvider).valueOrNull ?? [])))}',
                color: kPrimaryBlue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_saving ? '保存中...' : '确认保存'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: kInkSecondary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white.withValues(alpha: 0.56),
      side: BorderSide(color: kInkSecondary.withValues(alpha: 0.14)),
    );
  }
}

class _QuickInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _QuickInfoPill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? kInkSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: resolvedColor == kInkSecondary ? null : resolvedColor,
              fontWeight: resolvedColor == kInkSecondary
                  ? null
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreEditor extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double> onChanged;
  final VoidCallback onClear;

  const _ScoreEditor({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                value == null ? '未评分' : value!.toStringAsFixed(1),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  unawaited(InteractionFeedback.selection(context));
                  onClear();
                },
                child: const Text('清空'),
              ),
            ],
          ),
          Slider(
            value: value ?? 3.0,
            min: 0,
            max: 5,
            divisions: 10,
            label: (value ?? 3.0).toStringAsFixed(1),
            onChanged: (nextValue) {
              unawaited(InteractionFeedback.selection(context));
              onChanged(nextValue);
            },
          ),
        ],
      ),
    );
  }
}
