import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/attendance.dart';
import '../../core/providers/attendance_provider.dart';
import '../../core/providers/invalidation_helper.dart';
import '../../core/utils/fee_calculator.dart';
import '../constants.dart';
import '../theme.dart';
import '../utils/toast.dart';
import 'time_wheel_picker.dart';

class AttendanceEditSheet extends ConsumerStatefulWidget {
  final Attendance record;
  const AttendanceEditSheet({super.key, required this.record});

  @override
  ConsumerState<AttendanceEditSheet> createState() => _AttendanceEditSheetState();
}

class _AttendanceEditSheetState extends ConsumerState<AttendanceEditSheet> {
  late String _status;
  late DateTime _date;
  late String _startTime;
  late String _endTime;
  late TextEditingController _noteCtrl;
  bool _saving = false;

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
    _status = widget.record.status;
    _date = DateTime.parse(widget.record.date);
    _startTime = widget.record.startTime;
    _endTime = widget.record.endTime;
    _noteCtrl = TextEditingController(text: widget.record.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
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

      // 冲突检测（排除自身）
      final conflict = await dao.findConflict(
        widget.record.studentId, _dateStr(), _startTime, _endTime,
        excludeId: widget.record.id,
      );
      if (conflict != null && mounted) {
        final ok = await AppToast.showConfirm(
          context,
          '该时段已有其他出勤记录，是否继续保存？',
        );
        if (!ok) return;
      }

      final statusEnum = AttendanceStatus.values.firstWhere((e) => e.name == _status);
      final newFee = FeeCalculator.calcFee(statusEnum, widget.record.priceSnapshot);

      final updated = widget.record.copyWith(
        status: _status,
        date: _dateStr(),
        startTime: _startTime,
        endTime: _endTime,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        feeAmount: newFee,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await dao.update(updated);
      _invalidate();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final confirm = await AppToast.showConfirm(context, '确认删除此出勤记录？');
    if (!confirm) return;

    setState(() => _saving = true);
    await ref.read(attendanceDaoProvider).delete(widget.record.id);
    _invalidate();
    if (mounted) Navigator.of(context).pop();
  }

  void _invalidate() {
    invalidateAfterAttendanceChange(ref);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: kInkSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('编辑出勤记录', style: theme.textTheme.titleLarge?.copyWith(fontSize: 21)),
              TextButton(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: kRed),
                child: const Text('删除'),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
                    final picked = await showTimeWheelPicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.parse(parts[0]),
                        minute: int.parse(parts[1]),
                      ),
                      label: '开始时间',
                    );
                    if (picked != null) {
                      setState(() {
                        _startTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
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
                    final picked = await showTimeWheelPicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.parse(parts[0]),
                        minute: int.parse(parts[1]),
                      ),
                      label: '结束时间',
                    );
                    if (picked != null) {
                      setState(() {
                        _endTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
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
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: '备注'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? '保存中...' : '保存')),
        ],
      ),
    );
  }
}
