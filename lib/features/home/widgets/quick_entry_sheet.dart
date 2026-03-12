import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/class_template_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
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
  }

  String _dateStr() => formatDate(_date);

  Future<void> _save() async {
    if (_saving) return;
    if (_endTime.compareTo(_startTime) <= 0) {
      AppToast.showError(context, '结束时间必须晚于开始时间');
      return;
    }
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

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
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
                    color: _step >= i
                        ? theme.colorScheme.primary
                        : theme.dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: [_buildStep0(controller), _buildStep1(), _buildStep2()][_step]),
        ],
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
            decoration: const InputDecoration(
              hintText: '搜索学生',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() {
                    if (allFilteredSelected) {
                      _selectedIds.removeAll(filteredIds);
                    } else {
                      _selectedIds.addAll(filteredIds);
                    }
                  }),
                  icon: Icon(
                    allFilteredSelected
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 20,
                  ),
                  label: Text(allFilteredSelected ? '取消全选' : '全选'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _showSuspended = !_showSuspended),
                  icon: Icon(
                    _showSuspended ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  label: Text(_showSuspended ? '隐藏休学' : '显示休学'),
                ),
              ],
            ),
          ),
        if (filtered.isEmpty) const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            controller: controller,
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final m = filtered[i];
              final selected = _selectedIds.contains(m.student.id);
              return CheckboxListTile(
                title: Text(displayNames[m.student.id] ?? m.student.name),
                subtitle: Text('¥${m.student.pricePerClass.toStringAsFixed(0)}/节'),
                value: selected,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedIds.add(m.student.id);
                  } else {
                    _selectedIds.remove(m.student.id);
                  }
                }),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedIds.isEmpty ? null : () => setState(() => _step = 1),
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
          Text('选择模板', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: templates
                .map(
                  (t) => ActionChip(
                    label: Text('${t.name} ${t.startTime}-${t.endTime}'),
                    onPressed: () => setState(() {
                      _startTime = t.startTime;
                      _endTime = t.endTime;
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('日期：${_dateStr()}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _date = d);
          },
        ),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final parts = _startTime.split(':');
                  final t = await showTimeWheelPicker(
                    context: context,
                    initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                    label: '开始时间',
                  );
                  if (t != null) {
                    setState(() {
                      _startTime = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '开始时间'),
                  child: Text(_startTime),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final parts = _endTime.split(':');
                  final t = await showTimeWheelPicker(
                    context: context,
                    initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                    label: '结束时间',
                  );
                  if (t != null) {
                    setState(() {
                      _endTime = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '结束时间'),
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
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
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
              Text('日期：${_dateStr()}  $_startTime-$_endTime'),
              Text('状态：${_statuses.firstWhere((s) => s.$1 == _status).$2}'),
              const SizedBox(height: 12),
              Text('学生列表：', style: theme.textTheme.titleSmall),
              ...selected.map((m) {
                final fee =
                    FeeCalculator.calcFee(statusEnum, m.student.pricePerClass);
                return ListTile(
                  dense: true,
                  title: Text(displayNames[m.student.id] ?? m.student.name),
                  trailing: Text('¥${fee.toStringAsFixed(0)}'),
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
                  child: const Text('上一步'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
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
