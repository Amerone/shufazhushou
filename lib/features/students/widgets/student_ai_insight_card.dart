import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ai_analysis_note_entry.dart';
import '../../../core/models/student.dart';
import '../../../core/models/student_insight_result.dart';
import '../../../core/providers/ai_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/services/ai_analysis_note_codec.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';

enum _InsightDisplaySource { none, saved, generated }

class StudentAiInsightCard extends ConsumerStatefulWidget {
  final Student student;
  final VoidCallback? onSaved;

  const StudentAiInsightCard({super.key, required this.student, this.onSaved});

  @override
  ConsumerState<StudentAiInsightCard> createState() =>
      _StudentAiInsightCardState();
}

class _StudentAiInsightCardState extends ConsumerState<StudentAiInsightCard> {
  static const _maxAnalyzeRecords = 12;

  bool _analyzing = false;
  bool _saving = false;
  bool _expanded = true;
  String? _errorText;
  StudentInsightResult? _result;
  DateTime? _analyzedAt;
  DateTime? _savedAt;
  _InsightDisplaySource _displaySource = _InsightDisplaySource.none;
  String? _savedInsightSignature;

  @override
  void initState() {
    super.initState();
    _restoreSavedInsight(initialLoad: true);
  }

  @override
  void didUpdateWidget(covariant StudentAiInsightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id) {
      _restoreSavedInsight(force: true);
      return;
    }
    if (oldWidget.student.note != widget.student.note) {
      _restoreSavedInsight(
        force: _displaySource != _InsightDisplaySource.generated,
      );
    }
  }

  Future<void> _analyzeInsight() async {
    final service = ref.read(studentInsightAnalysisServiceProvider);
    if (service == null) {
      AppToast.showError(context, '请先在设置中完成 AI 配置。');
      return;
    }

    setState(() {
      _analyzing = true;
      _errorText = null;
      _result = null;
      _analyzedAt = null;
      _savedAt = null;
      _displaySource = _InsightDisplaySource.none;
    });

    try {
      final records = await ref
          .read(attendanceDaoProvider)
          .getByStudentPaged(widget.student.id, _maxAnalyzeRecords, 0);
      final result = await service.analyzeStudentInsight(
        widget.student,
        records,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _analyzedAt = DateTime.now();
        _expanded = true;
        _displaySource = _InsightDisplaySource.generated;
      });
    } catch (error) {
      if (!mounted) return;
      final errorText = _formatError(error);
      _restoreSavedInsight(force: true);
      if (!mounted) return;
      setState(() => _errorText = errorText);
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  Future<void> _saveAnalysisToNote() async {
    final result = _result;
    if (result == null || _saving || _savedAt != null) return;

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final noteContent = _buildNoteContent(result);

    try {
      final studentDao = ref.read(studentDaoProvider);
      final currentStudent =
          await studentDao.getById(widget.student.id) ?? widget.student;
      final existingInsightContent = AiAnalysisNoteCodec.latestContent(
        currentStudent.note,
        type: 'student_insight',
      );
      if (existingInsightContent?.trim() == noteContent) {
        if (!mounted) return;
        setState(() {
          _savedAt = DateTime.now();
          _displaySource = _InsightDisplaySource.saved;
        });
        _restoreSavedInsight(force: true);
        AppToast.showSuccess(context, '当前学生洞察已存在于学生备注中。');
        return;
      }

      final analyzedAt = _analyzedAt ?? DateTime.now();
      final mergedNote = AiAnalysisNoteCodec.appendStudentInsight(
        existingNote: currentStudent.note,
        analysisText: noteContent,
        analyzedAt: analyzedAt,
      );

      await studentDao.update(
        currentStudent.copyWith(
          note: mergedNote,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await ref.read(studentProvider.notifier).reload();

      if (!mounted) return;
      setState(() {
        _savedAt = DateTime.now();
        _displaySource = _InsightDisplaySource.saved;
      });
      widget.onSaved?.call();
      AppToast.showSuccess(context, '学生洞察已保存到学生备注。');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = _formatError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _restoreSavedInsight({bool initialLoad = false, bool force = false}) {
    final latestEntry = AiAnalysisNoteCodec.latestEntry(
      widget.student.note,
      type: 'student_insight',
    );
    final savedContent = latestEntry?.content.trim();
    final nextSignature = savedContent == null || savedContent.isEmpty
        ? null
        : '${latestEntry!.createdAt.toIso8601String()}::$savedContent';
    final hasUnsavedGeneratedResult =
        _displaySource == _InsightDisplaySource.generated &&
        _result != null &&
        _savedAt == null;

    if (hasUnsavedGeneratedResult && !force) {
      return;
    }
    if (!initialLoad && !force && nextSignature == _savedInsightSignature) {
      return;
    }

    if (initialLoad) {
      _applySavedInsight(latestEntry, savedContent, nextSignature);
      return;
    }

    if (!mounted) return;
    setState(() {
      _applySavedInsight(latestEntry, savedContent, nextSignature);
    });
  }

  void _applySavedInsight(
    AiAnalysisNoteEntry? latestEntry,
    String? savedContent,
    String? nextSignature,
  ) {
    _savedInsightSignature = nextSignature;
    if (savedContent == null || savedContent.isEmpty || latestEntry == null) {
      if (_displaySource == _InsightDisplaySource.saved ||
          _result == null ||
          _savedAt != null) {
        _result = null;
        _analyzedAt = null;
        _savedAt = null;
        _displaySource = _InsightDisplaySource.none;
      }
      return;
    }

    _result = StudentInsightResult.fromSavedNote(rawText: savedContent);
    _analyzedAt = latestEntry.createdAt;
    _savedAt = latestEntry.createdAt;
    _displaySource = _InsightDisplaySource.saved;
    _expanded = true;
    _errorText = null;
  }

  String _formatError(Object error) {
    final text = error.toString().trim();
    const knownPrefixes = <String>[
      'Exception: ',
      'FormatException: ',
      'VisionAnalysisException: ',
    ];
    for (final prefix in knownPrefixes) {
      if (text.startsWith(prefix)) {
        return text.substring(prefix.length).trim();
      }
    }
    final separatorIndex = text.indexOf(': ');
    if (separatorIndex > 0) {
      return text.substring(separatorIndex + 2).trim();
    }
    return text.isEmpty ? '分析失败，请稍后重试。' : text;
  }

  String _buildNoteContent(StudentInsightResult result) {
    final lines = <String>[];
    if (result.summary.isNotEmpty) {
      lines.add('总体画像：${result.summary}');
    }
    if (result.attendancePattern.isNotEmpty) {
      lines.add('上课规律：${result.attendancePattern}');
    }
    if (result.writingObservation.isNotEmpty) {
      lines.add('作品观察：${result.writingObservation}');
    }
    if (result.progressInsight.isNotEmpty) {
      lines.add('进步判断：${result.progressInsight}');
    }
    if (result.riskAlerts.isNotEmpty) {
      lines.add('风险提醒：');
      for (var i = 0; i < result.riskAlerts.length; i++) {
        lines.add('${i + 1}. ${result.riskAlerts[i]}');
      }
    }
    if (result.teachingSuggestions.isNotEmpty) {
      lines.add('教学建议：');
      for (var i = 0; i < result.teachingSuggestions.length; i++) {
        lines.add('${i + 1}. ${result.teachingSuggestions[i]}');
      }
    }
    if (result.parentCommunicationTip.isNotEmpty) {
      lines.add('家长沟通：${result.parentCommunicationTip}');
    }

    if (lines.isNotEmpty) {
      return lines.join('\n');
    }
    return result.rawText.trim().isEmpty ? '暂无学生洞察结果。' : result.rawText.trim();
  }

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = ref.watch(studentInsightAnalysisServiceProvider);
    final noteEntries = AiAnalysisNoteCodec.decodeEntries(widget.student.note);
    final handwritingCount = noteEntries
        .where((entry) => entry.type == 'handwriting')
        .length;
    final savedProgressCount = noteEntries
        .where((entry) => entry.type == 'progress')
        .length;
    final canAnalyze = service != null && !_analyzing;
    final canSave = _result != null && !_saving && _savedAt == null;
    final statusLabel = switch (_displaySource) {
      _InsightDisplaySource.saved => '已保存',
      _InsightDisplaySource.generated => '已生成',
      _ => '待生成',
    };
    final hasSavedInsight = _displaySource == _InsightDisplaySource.saved;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('AI 学生洞察', style: theme.textTheme.titleMedium),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kSealRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kSealRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.image_search_outlined,
                label: '作品分析 $handwritingCount 条',
                color: handwritingCount > 0 ? kPrimaryBlue : kInkSecondary,
              ),
              _MetaChip(
                icon: Icons.trending_up_outlined,
                label: '学习分析 $savedProgressCount 条',
                color: savedProgressCount > 0 ? kGreen : kInkSecondary,
              ),
            ],
          ),
          if (handwritingCount == 0) ...[
            const SizedBox(height: 10),
            Text(
              '先做作品分析，洞察会更准。',
              style: theme.textTheme.bodySmall?.copyWith(color: kOrange),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: canAnalyze ? _analyzeInsight : null,
              icon: _analyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.insights_outlined, size: 18),
              label: Text(
                _analyzing
                    ? '分析中...'
                    : service == null
                    ? '先完成 AI 配置'
                    : _result == null
                    ? '分析学生洞察'
                    : '重新分析学生洞察',
              ),
            ),
          ),
          if (service == null) ...[
            const SizedBox(height: 10),
            Text(
              '未配置时不会发起 AI 请求，请先在设置页完成 AI 配置。',
              style: theme.textTheme.bodySmall?.copyWith(color: kOrange),
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSealRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(color: kSealRed),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            _InsightQuickUsePanel(
              result: _result!,
              hasSavedInsight: hasSavedInsight,
            ),
            const SizedBox(height: 12),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: _expanded,
                onExpansionChanged: (value) {
                  setState(() => _expanded = value);
                },
                title: Text(
                  '查看洞察结果',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: _analyzedAt == null
                    ? null
                    : Text(
                        '生成时间：${_formatTime(_analyzedAt!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                children: [
                  _InsightBlock(title: '总体画像', content: _result!.summary),
                  _InsightBlock(
                    title: '上课规律',
                    content: _result!.attendancePattern,
                  ),
                  _InsightBlock(
                    title: '作品观察',
                    content: _result!.writingObservation,
                  ),
                  _InsightBlock(
                    title: '进步判断',
                    content: _result!.progressInsight,
                  ),
                  if (_result!.riskAlerts.isNotEmpty)
                    _InsightListBlock(
                      title: '风险提醒',
                      items: _result!.riskAlerts,
                      color: kSealRed,
                    ),
                  if (_result!.teachingSuggestions.isNotEmpty)
                    _InsightListBlock(
                      title: '教学建议',
                      items: _result!.teachingSuggestions,
                      color: kGreen,
                    ),
                  _InsightBlock(
                    title: '家长沟通',
                    content: _result!.parentCommunicationTip,
                  ),
                  if (!_result!.isStructured &&
                      _result!.rawText.trim().isNotEmpty)
                    _InsightBlock(title: '原始结果', content: _result!.rawText),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: canSave ? _saveAnalysisToNote : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _saving
                      ? '保存中...'
                      : _savedAt != null
                      ? '已保存到学生备注'
                      : '保存洞察到学生备注',
                ),
              ),
            ),
            if (_savedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '已保存于 ${_formatTime(_savedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: kGreen),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InsightBlock extends StatelessWidget {
  final String title;
  final String content;

  const _InsightBlock({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = content.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: kPrimaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text.isEmpty ? '暂无内容。' : text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightListBlock extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;

  const _InsightListBlock({
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 6),
                child: Text(
                  '${i + 1}. ${items[i]}',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InsightQuickUsePanel extends StatelessWidget {
  final StudentInsightResult result;
  final bool hasSavedInsight;

  const _InsightQuickUsePanel({
    required this.result,
    required this.hasSavedInsight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lessonSuggestion = result.teachingSuggestions.isEmpty
        ? ''
        : result.teachingSuggestions.first;
    final riskAlert = result.riskAlerts.isEmpty ? '' : result.riskAlerts.first;
    final parentTip = result.parentCommunicationTip.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                hasSavedInsight ? '老师现在可直接用' : '这次分析建议先这样用',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: kPrimaryBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasSavedInsight)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '已保存',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: kGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (lessonSuggestion.isNotEmpty)
            _QuickUseLine(
              label: '下节课先做',
              content: lessonSuggestion,
              color: kGreen,
            ),
          if (riskAlert.isNotEmpty) ...[
            if (lessonSuggestion.isNotEmpty) const SizedBox(height: 8),
            _QuickUseLine(label: '课堂留意', content: riskAlert, color: kSealRed),
          ],
          if (parentTip.isNotEmpty) ...[
            if (lessonSuggestion.isNotEmpty || riskAlert.isNotEmpty)
              const SizedBox(height: 8),
            _QuickUseLine(
              label: '家长可说',
              content: parentTip,
              color: kPrimaryBlue,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickUseLine extends StatelessWidget {
  final String label;
  final String content;
  final Color color;

  const _QuickUseLine({
    required this.label,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
        children: [
          TextSpan(
            text: '$label：',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: content,
            style: theme.textTheme.bodySmall?.copyWith(color: kInkSecondary),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
