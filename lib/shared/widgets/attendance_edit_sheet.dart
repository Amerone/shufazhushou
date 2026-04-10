import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/attendance.dart';
import '../../core/models/structured_attendance_feedback.dart';
import '../../core/providers/attendance_provider.dart';
import '../../core/providers/invalidation_helper.dart';
import '../../core/utils/fee_calculator.dart';
import '../constants.dart';
import '../theme.dart';
import '../utils/interaction_feedback.dart';
import '../utils/toast.dart';
import 'glass_card.dart';
import 'time_wheel_picker.dart';

class AttendanceEditSheet extends ConsumerStatefulWidget {
  final Attendance record;
  final Future<void> Function()? onAnalyzeArtwork;

  const AttendanceEditSheet({
    super.key,
    required this.record,
    this.onAnalyzeArtwork,
  });

  @override
  ConsumerState<AttendanceEditSheet> createState() =>
      _AttendanceEditSheetState();
}

class _AttendanceEditSheetState extends ConsumerState<AttendanceEditSheet> {
  late Attendance _record;
  late String _status;
  late DateTime _date;
  late String _startTime;
  late String _endTime;
  late TextEditingController _noteCtrl;
  late TextEditingController _homePracticeCtrl;
  final Set<String> _lessonFocusTags = <String>{};
  double? _strokeQuality;
  double? _structureAccuracy;
  double? _rhythmConsistency;
  bool _saving = false;
  bool _analyzingArtwork = false;

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
    _record = widget.record;
    _status = _record.status;
    _date = DateTime.parse(_record.date);
    _startTime = _record.startTime;
    _endTime = _record.endTime;
    _noteCtrl = TextEditingController(text: _record.note ?? '');
    _homePracticeCtrl = TextEditingController(
      text: _record.homePracticeNote ?? '',
    );
    _lessonFocusTags.addAll(_record.lessonFocusTags);
    _strokeQuality = _record.progressScores?.strokeQuality;
    _structureAccuracy = _record.progressScores?.structureAccuracy;
    _rhythmConsistency = _record.progressScores?.rhythmConsistency;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
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

  double _currentFeePreview() {
    final statusEnum = AttendanceStatus.values.firstWhere(
      (item) => item.name == _status,
    );
    return FeeCalculator.calcFee(statusEnum, _record.priceSnapshot);
  }

  Future<Attendance?> _loadLatestRecord() {
    return ref.read(attendanceDaoProvider).getById(_record.id);
  }

  void _replaceHomePracticeDraft(String? value) {
    final nextText = value ?? '';
    _homePracticeCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  Future<void> _refreshAfterExternalUpdate() async {
    final latestRecord = await _loadLatestRecord();
    if (!mounted || latestRecord == null) return;

    setState(() {
      _record = latestRecord;
      _replaceHomePracticeDraft(latestRecord.homePracticeNote);
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
      final latestRecord = await dao.getById(_record.id);
      if (latestRecord == null) {
        throw StateError('未找到对应的出勤记录。');
      }

      // 冲突检测（排除自身）
      final conflict = await dao.findConflict(
        latestRecord.studentId,
        _dateStr(),
        _startTime,
        _endTime,
        excludeId: latestRecord.id,
      );
      if (conflict != null && mounted) {
        final ok = await AppToast.showConfirm(context, '该时段已有其他出勤记录，是否继续保存？');
        if (!ok) return;
      }

      final statusEnum = AttendanceStatus.values.firstWhere(
        (e) => e.name == _status,
      );
      final newFee = FeeCalculator.calcFee(
        statusEnum,
        latestRecord.priceSnapshot,
      );

      final updated = latestRecord.copyWith(
        status: _status,
        date: _dateStr(),
        startTime: _startTime,
        endTime: _endTime,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        lessonFocusTags: _lessonFocusTags.toList(growable: false),
        homePracticeNote: _homePracticeCtrl.text.trim().isEmpty
            ? null
            : _homePracticeCtrl.text.trim(),
        progressScores: _buildProgressScores(),
        feeAmount: newFee,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await dao.update(updated);
      _record = updated;
      _invalidate();
      if (!mounted) return;
      await InteractionFeedback.seal(context);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, error.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final confirm = await AppToast.showConfirm(context, '确认删除此出勤记录？');
    if (!confirm) return;

    setState(() => _saving = true);
    try {
      await ref.read(attendanceDaoProvider).delete(_record.id);
      _invalidate();
      if (!mounted) return;
      await InteractionFeedback.seal(context);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, error.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _invalidate() {
    invalidateAfterAttendanceChange(ref);
  }

  Future<void> _analyzeArtwork() async {
    final analyzeArtwork = widget.onAnalyzeArtwork;
    if (analyzeArtwork == null || _saving || _analyzingArtwork) return;

    FocusScope.of(context).unfocus();
    setState(() => _analyzingArtwork = true);
    try {
      await analyzeArtwork();
      await _refreshAfterExternalUpdate();
    } finally {
      if (mounted) {
        setState(() => _analyzingArtwork = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '编辑出勤记录',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '可调整日期、时间、状态和备注，保存后会同步更新费用。',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _delete,
                    style: TextButton.styleFrom(foregroundColor: kRed),
                    child: const Text('删除'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statuses
                    .map(
                      (s) => ChoiceChip(
                        label: Text(s.$2),
                        selected: _status == s.$1,
                        onSelected: (_) {
                          unawaited(InteractionFeedback.selection(context));
                          setState(() => _status = s.$1);
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: kPrimaryBlue.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '课时单价 ¥${_record.priceSnapshot.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kPrimaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '本次扣费 ¥${_currentFeePreview().toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: kPrimaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d == null || !context.mounted) return;
                  await InteractionFeedback.selection(context);
                  if (!context.mounted) return;
                  setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '日期',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.5),
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
                        final picked = await showTimeWheelPicker(
                          context: context,
                          initialTime: parseTime(_startTime),
                          label: '开始时间',
                        );
                        if (picked == null || !context.mounted) return;
                        await InteractionFeedback.selection(context);
                        if (!context.mounted) return;
                        setState(() {
                          _startTime = formatTime(picked);
                        });
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '开始时间',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.5),
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
                        final picked = await showTimeWheelPicker(
                          context: context,
                          initialTime: parseTime(_endTime),
                          label: '结束时间',
                        );
                        if (picked == null || !context.mounted) return;
                        await InteractionFeedback.selection(context);
                        if (!context.mounted) return;
                        setState(() {
                          _endTime = formatTime(picked);
                        });
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '结束时间',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.5),
                        ),
                        child: Text(_endTime),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '备注',
                  hintText: '可记录补课原因、课堂说明或家长反馈。',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              if (widget.onAnalyzeArtwork != null) ...[
                const SizedBox(height: 16),
                _ArtworkAnalysisPanel(
                  analyzing: _analyzingArtwork,
                  onAnalyze: _analyzeArtwork,
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('课堂重点（可选）', style: theme.textTheme.titleSmall),
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
                  labelText: '课后练习建议（可选）',
                  hintText: '例如：本周每天 15 分钟，先慢后快。',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('进步评分（0-5，可选）', style: theme.textTheme.titleSmall),
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_saving ? '保存中...' : '保存修改'),
              ),
            ],
          ),
        ),
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
        color: Colors.white.withValues(alpha: 0.5),
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

class _ArtworkAnalysisPanel extends StatelessWidget {
  final bool analyzing;
  final VoidCallback onAnalyze;

  const _ArtworkAnalysisPanel({
    required this.analyzing,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSealRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSealRed.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kSealRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: kSealRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 作品分析',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '拍照或从相册选择课堂作品，AI 会生成观察结果和课后练习建议。',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: analyzing ? null : onAnalyze,
              icon: analyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(analyzing ? '分析中...' : '拍照 / 选照片分析'),
            ),
          ),
        ],
      ),
    );
  }
}
