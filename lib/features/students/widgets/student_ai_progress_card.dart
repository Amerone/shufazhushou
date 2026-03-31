import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/progress_analysis_result.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/ai_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/services/ai_analysis_note_codec.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';

class StudentAiProgressCard extends ConsumerStatefulWidget {
  final Student student;
  final VoidCallback? onSaved;

  const StudentAiProgressCard({
    super.key,
    required this.student,
    this.onSaved,
  });

  @override
  ConsumerState<StudentAiProgressCard> createState() =>
      _StudentAiProgressCardState();
}

class _StudentAiProgressCardState
    extends ConsumerState<StudentAiProgressCard> {
  static const _maxAnalyzeRecords = 10;

  bool _analyzing = false;
  bool _saving = false;
  bool _expanded = true;
  String? _errorText;
  ProgressAnalysisResult? _analysisResult;
  DateTime? _analyzedAt;
  DateTime? _savedAt;

  Future<void> _analyzeProgress() async {
    final service = ref.read(progressAnalysisServiceProvider);
    if (service == null) {
      AppToast.showError(
        context,
        '\u8bf7\u5148\u5728\u8bbe\u7f6e\u4e2d\u5b8c\u6210 AI \u914d\u7f6e\u3002',
      );
      return;
    }

    setState(() {
      _analyzing = true;
      _errorText = null;
      _analysisResult = null;
      _analyzedAt = null;
      _savedAt = null;
    });

    try {
      final records = await ref
          .read(attendanceDaoProvider)
          .getByStudentPaged(widget.student.id, _maxAnalyzeRecords, 0);
      if (records.isEmpty) {
        if (!mounted) return;
        setState(() {
          _analysisResult = null;
          _errorText =
              '\u6682\u65e0\u53ef\u7528\u4e8e\u5206\u6790\u7684\u8fd1\u671f\u51fa\u52e4\u8bb0\u5f55\u3002';
        });
        return;
      }

      final result = await service.analyzeStudentProgress(
        widget.student,
        records,
      );

      if (!mounted) return;
      setState(() {
        _analysisResult = result;
        _analyzedAt = DateTime.now();
        _expanded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _analysisResult = null;
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  Future<void> _saveAnalysisToNote() async {
    final result = _analysisResult;
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
      final existingProgressContent = AiAnalysisNoteCodec.latestContent(
        currentStudent.note,
        type: 'progress',
      );
      if (existingProgressContent?.trim() == noteContent) {
        if (!mounted) return;
        setState(() => _savedAt = DateTime.now());
        AppToast.showSuccess(
          context,
          '\u5f53\u524d\u5206\u6790\u5df2\u5b58\u5728\u4e8e\u5b66\u751f\u5907\u6ce8\u4e2d\u3002',
        );
        return;
      }

      final analyzedAt = _analyzedAt ?? DateTime.now();
      final mergedNote = AiAnalysisNoteCodec.appendProgressAnalysis(
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
      setState(() => _savedAt = DateTime.now());
      widget.onSaved?.call();
      AppToast.showSuccess(
        context,
        '\u5206\u6790\u7ed3\u679c\u5df2\u4fdd\u5b58\u5230\u5b66\u751f\u5907\u6ce8\u3002',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _buildNoteContent(ProgressAnalysisResult result) {
    final lines = <String>[];
    if (result.overallAssessment.isNotEmpty) {
      lines.add(
        '\u603b\u4f53\u8bc4\u4ef7\uff1a${result.overallAssessment}',
      );
    }
    if (result.trendAnalysis.isNotEmpty) {
      lines.add('\u8d8b\u52bf\u5206\u6790\uff1a${result.trendAnalysis}');
    }
    if (result.strengths.isNotEmpty) {
      lines.add('\u4f18\u52bf\u65b9\u9762\uff1a${result.strengths}');
    }
    if (result.areasToImprove.isNotEmpty) {
      lines.add(
        '\u9700\u52a0\u5f3a\u65b9\u9762\uff1a${result.areasToImprove}',
      );
    }
    if (result.teachingSuggestions.isNotEmpty) {
      lines.add('\u6559\u5b66\u5efa\u8bae\uff1a');
      for (var i = 0; i < result.teachingSuggestions.length; i++) {
        lines.add('${i + 1}. ${result.teachingSuggestions[i]}');
      }
    }

    if (lines.isNotEmpty) {
      return lines.join('\n');
    }

    final fallback = result.rawText.trim();
    return fallback.isEmpty ? '\u6682\u65e0\u5206\u6790\u7ed3\u679c\u3002' : fallback;
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
    final service = ref.watch(progressAnalysisServiceProvider);
    final canAnalyze = service != null && !_analyzing;
    final result = _analysisResult;
    final canSave = result != null && !_saving && _savedAt == null;

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
              Text(
                'AI \u5b66\u4e60\u5206\u6790',
                style: theme.textTheme.titleMedium,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result == null
                      ? '\u5f85\u751f\u6210'
                      : '\u5df2\u751f\u6210',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '\u603b\u7ed3\u6700\u8fd1 10 \u6761\u51fa\u52e4\u8bb0\u5f55\uff0c\u5e76\u7531\u4f60\u51b3\u5b9a\u662f\u5426\u4fdd\u5b58\u5230\u5b66\u751f\u5907\u6ce8\u3002',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: canAnalyze ? _analyzeProgress : null,
              icon: _analyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(
                _analyzing
                    ? '\u5206\u6790\u4e2d...'
                    : '\u5206\u6790\u8fd1\u671f\u5b66\u4e60\u8fdb\u5c55',
              ),
            ),
          ),
          if (service == null) ...[
            const SizedBox(height: 10),
            Text(
              '\u4f7f\u7528\u524d\u8bf7\u5148\u5728\u8bbe\u7f6e\u9875\u5b8c\u6210 AI \u914d\u7f6e\u3002',
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
          if (result != null) ...[
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
                  '\u67e5\u770b\u5206\u6790\u7ed3\u679c',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: _analyzedAt == null
                    ? null
                    : Text(
                        '\u751f\u6210\u65f6\u95f4\uff1a${_formatTime(_analyzedAt!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                children: [
                  if (result.overallAssessment.isNotEmpty)
                    _AnalysisBlock(
                      label: '\u603b\u4f53\u8bc4\u4ef7',
                      content: result.overallAssessment,
                    ),
                  if (result.trendAnalysis.isNotEmpty)
                    _AnalysisBlock(
                      label: '\u8d8b\u52bf\u5206\u6790',
                      content: result.trendAnalysis,
                    ),
                  if (result.strengths.isNotEmpty)
                    _AnalysisBlock(
                      label: '\u4f18\u52bf\u65b9\u9762',
                      content: result.strengths,
                    ),
                  if (result.areasToImprove.isNotEmpty)
                    _AnalysisBlock(
                      label: '\u9700\u52a0\u5f3a\u65b9\u9762',
                      content: result.areasToImprove,
                    ),
                  if (result.teachingSuggestions.isNotEmpty)
                    _SuggestionsBlock(items: result.teachingSuggestions),
                  if (!result.isStructured && result.rawText.trim().isNotEmpty)
                    _AnalysisBlock(
                      label: '\u539f\u59cb\u7ed3\u679c',
                      content: result.rawText,
                    ),
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
                      ? '\u4fdd\u5b58\u4e2d...'
                      : _savedAt != null
                          ? '\u5df2\u4fdd\u5b58\u5230\u5b66\u751f\u5907\u6ce8'
                          : '\u4fdd\u5b58\u5206\u6790\u5230\u5b66\u751f\u5907\u6ce8',
                ),
              ),
            ),
            if (_savedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '\u5df2\u4fdd\u5b58\u4e8e ${_formatTime(_savedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: kGreen),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AnalysisBlock extends StatelessWidget {
  final String label;
  final String content;

  const _AnalysisBlock({
    required this.label,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: kPrimaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              content,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsBlock extends StatelessWidget {
  final List<String> items;

  const _SuggestionsBlock({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kPrimaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\u6559\u5b66\u5efa\u8bae',
              style: theme.textTheme.bodySmall?.copyWith(
                color: kPrimaryBlue,
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
