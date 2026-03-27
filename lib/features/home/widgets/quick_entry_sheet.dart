import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/structured_attendance_feedback.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/class_template_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/time_wheel_picker.dart';

class QuickEntrySheet extends ConsumerStatefulWidget {
  const QuickEntrySheet({super.key});

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

  static const _statuses = [
    ('present', '出勤'),
    ('late', '迟到'),
    ('leave', '请假'),
    ('absent', '缺勤'),
    ('trial', '试听'),
  ];

  @override
  void initState() {
    super.initState();
    _date = ref.read(selectedDateProvider);
    _homePracticeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _homePracticeCtrl.dispose();
    super.dispose();
  }

  String _dateStr() => formatDate(_date);

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
      final selectedStudents =
          students.where((m) => _selectedIds.contains(m.student.id)).toList();

      final allStudents = students.map((m) => m.student).toList();
      final displayNames = buildDisplayNameMap(allStudents);
      final conflicts = <String>[];
      final conflictIds = <String, String>{}; // studentId -> conflicting attendance id

      for (final m in selectedStudents) {
        final conflict =
            await dao.findConflict(m.student.id, _dateStr(), _startTime, _endTime);
        if (conflict != null) {
          conflicts.add(displayNames[m.student.id] ?? m.student.name);
          conflictIds[m.student.id] = conflict.id;
        }
      }

      if (conflicts.isNotEmpty && mounted) {
        final ok = await AppToast.showConfirm(
          context,
          '以下学生该时段已有记录：${conflicts.join('、')}，是否覆盖？',
        );
        if (!ok) return;
      }

      final statusEnum =
          AttendanceStatus.values.firstWhere((e) => e.name == _status);
      final now = DateTime.now().millisecondsSinceEpoch;

      final records = <Attendance>[];
      for (final m in selectedStudents) {
        final price = m.student.pricePerClass;
        final fee = FeeCalculator.calcFee(statusEnum, price);
        records.add(Attendance(
          id: const Uuid().v4(),
          studentId: m.student.id,
          date: _dateStr(),
          startTime: _startTime,
          endTime: _endTime,
          status: _status,
          priceSnapshot: price,
          feeAmount: fee,
          lessonFocusTags: _lessonFocusTags.toList(growable: false),
          homePracticeNote: _homePracticeCtrl.text.trim().isEmpty
              ? null
              : _homePracticeCtrl.text.trim(),
          progressScores: _buildProgressScores(),
          createdAt: now,
          updatedAt: now,
        ));
      }

      await dao.batchInsertWithConflictReplace(records, conflictIds);

      invalidateAfterAttendanceChange(ref);

      if (mounted) {
        AppToast.showSuccess(context, '已保存 ${selectedStudents.length} 条出勤记录');
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                      ['选择学员', '设置课程', '确认提交'][_step],
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        '搜索并批量勾选本次需要记课的学员。',
                        '设置日期、时间和出勤状态。',
                        '提交前再确认一次课程信息和费用。',
                      ][_step],
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
                    3,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _step == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _step >= i ? theme.colorScheme.primary : theme.dividerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: [_buildStep0(controller), _buildStep1(), _buildStep2()][_step]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0(ScrollController controller) {
    final students = ref.watch(studentProvider).valueOrNull ?? [];
    final activeStudents = _showSuspended
        ? students
        : students.where((m) => m.student.status == 'active').toList();
    final filtered = _searchQuery.isEmpty
        ? activeStudents
        : activeStudents.where((m) {
            return m.student.name.contains(_searchQuery) ||
                (m.student.parentPhone?.contains(_searchQuery) ?? false);
          }).toList();

    final displayNames = buildDisplayNameMap(filtered.map((m) => m.student).toList());
    final filteredIds = filtered.map((m) => m.student.id).toSet();
    final allFilteredSelected = filteredIds.isNotEmpty &&
        filteredIds.every((id) => _selectedIds.contains(id));

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
          child: Row(
            children: [
              _QuickActionChip(
                icon: allFilteredSelected ? Icons.deselect : Icons.select_all,
                label: allFilteredSelected ? '取消全选' : '全选',
                onTap: filtered.isEmpty
                    ? null
                    : () => setState(() {
                          if (allFilteredSelected) {
                            _selectedIds.removeAll(filteredIds);
                          } else {
                            _selectedIds.addAll(filteredIds);
                          }
                        }),
              ),
              const SizedBox(width: 8),
              _QuickActionChip(
                icon: _showSuspended ? Icons.visibility_off : Icons.visibility,
                label: _showSuspended ? '隐藏休学' : '显示休学',
                onTap: () => setState(() => _showSuspended = !_showSuspended),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        const SizedBox(height: 10),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '没有找到符合条件的学员',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final m = filtered[i];
                    final selected = _selectedIds.contains(m.student.id);
                    final statusText = m.student.status == 'active' ? '在读' : '休学';
                    final statusColorValue = m.student.status == 'active' ? kGreen : kOrange;

                    return Container(
                      margin: EdgeInsets.only(bottom: i == filtered.length - 1 ? 0 : 10),
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
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedIds.remove(m.student.id);
                          } else {
                            _selectedIds.add(m.student.id);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selectedIds.add(m.student.id);
                                  } else {
                                    _selectedIds.remove(m.student.id);
                                  }
                                }),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayNames[m.student.id] ?? m.student.name,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (m.student.parentPhone?.isNotEmpty ?? false) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        m.student.parentPhone!,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _QuickInfoPill(
                                          icon: Icons.payments_outlined,
                                          label: '¥${m.student.pricePerClass.toStringAsFixed(0)}/节',
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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedIds.isEmpty ? null : () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('下一步（已选 ${_selectedIds.length} 人）'),
            ),
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
                    side: BorderSide(color: kInkSecondary.withValues(alpha: 0.14)),
                    onPressed: () => setState(() {
                      _startTime = t.startTime;
                      _endTime = t.endTime;
                    }),
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
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '上课日期',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  if (t != null) {
                    setState(() {
                      _startTime = formatTime(t);
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '开始时间',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  if (t != null) {
                    setState(() {
                      _endTime = formatTime(t);
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '结束时间',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          children: _statuses
              .map(
                (s) => ChoiceChip(
                  label: Text(s.$2),
                  selected: _status == s.$1,
                  onSelected: (_) => setState(() => _status = s.$1),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Text('课堂重点（可选）', style: theme.textTheme.titleSmall),
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
            labelText: '课后练习建议（可选）',
            hintText: '例如：每日临摹 15 分钟，重点观察起收笔节奏。',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.56),
          ),
        ),
        const SizedBox(height: 16),
        Text('进步评分（0-5，可选）', style: theme.textTheme.titleSmall),
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
          onChanged: (value) => setState(() => _structureAccuracy = value),
          onClear: () => setState(() => _structureAccuracy = null),
        ),
        _ScoreEditor(
          label: '节奏连贯',
          value: _rhythmConsistency,
          onChanged: (value) => setState(() => _rhythmConsistency = value),
          onClear: () => setState(() => _rhythmConsistency = null),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('上一步'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_endTime.compareTo(_startTime) <= 0) {
                    AppToast.showError(context, '结束时间必须晚于开始时间');
                    return;
                  }
                  setState(() => _step = 2);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('下一步'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final theme = Theme.of(context);
    final students = ref.watch(studentProvider).valueOrNull ?? [];
    final selected =
        students.where((m) => _selectedIds.contains(m.student.id)).toList();
    final displayNames =
        buildDisplayNameMap(selected.map((m) => m.student).toList());
    final statusEnum =
        AttendanceStatus.values.firstWhere((e) => e.name == _status);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('课程摘要', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickInfoPill(icon: Icons.calendar_today_outlined, label: _dateStr()),
                        _QuickInfoPill(icon: Icons.access_time_outlined, label: '$_startTime - $_endTime'),
                        _QuickInfoPill(
                          icon: Icons.flag_outlined,
                          label: _statuses.firstWhere((s) => s.$1 == _status).$2,
                          color: statusColor(_status),
                        ),
                        _QuickInfoPill(icon: Icons.groups_2_outlined, label: '${selected.length} 位学员'),
                        if (_lessonFocusTags.isNotEmpty)
                          _QuickInfoPill(
                            icon: Icons.auto_awesome_outlined,
                            label: '重点 ${_lessonFocusTags.length} 项',
                            color: kSealRed,
                          ),
                        if (_buildProgressScores() != null)
                          _QuickInfoPill(
                            icon: Icons.tune_outlined,
                            label: '已填写进步评分',
                            color: kGreen,
                          ),
                      ],
                    ),
                    if (_homePracticeCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '课后建议：${_homePracticeCtrl.text.trim()}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('学员列表', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...selected.map((m) {
                final fee = FeeCalculator.calcFee(statusEnum, m.student.pricePerClass);
                return Container(
                  margin: EdgeInsets.only(bottom: m == selected.last ? 0 : 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayNames[m.student.id] ?? m.student.name,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '课时单价 ¥${m.student.pricePerClass.toStringAsFixed(0)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '¥${fee.toStringAsFixed(0)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: kPrimaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_saving ? '保存中...' : '确认保存'),
                ),
              ),
            ],
          ),
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

  const _QuickInfoPill({
    required this.icon,
    required this.label,
    this.color,
  });

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
                  fontWeight: resolvedColor == kInkSecondary ? null : FontWeight.w700,
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
                onPressed: onClear,
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
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
