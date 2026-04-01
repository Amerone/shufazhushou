import 'package:flutter/material.dart';

import '../../../core/models/handwriting_analysis_result.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';

class AttendanceAiAnalysisSheet extends StatefulWidget {
  final HandwritingAnalysisResult result;
  final Future<void> Function() onApplySuggestion;

  const AttendanceAiAnalysisSheet({
    super.key,
    required this.result,
    required this.onApplySuggestion,
  });

  @override
  State<AttendanceAiAnalysisSheet> createState() =>
      _AttendanceAiAnalysisSheetState();
}

class _AttendanceAiAnalysisSheetState extends State<AttendanceAiAnalysisSheet> {
  bool _applying = false;

  Future<void> _handleApply() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await widget.onApplySuggestion();
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final suggestions = result.practiceSuggestions;
    final canApply = suggestions.isNotEmpty || result.summary.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              16,
        ),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: kInkSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '\u56fe\u7247\u5206\u6790\u7ed3\u679c',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      result.model,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kPrimaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AnalysisSection(
                label: '\u603b\u4f53\u6982\u89c8',
                content: result.summary,
              ),
              if (result.strokeObservation.isNotEmpty)
                _AnalysisSection(
                  label: '\u7b14\u753b\u89c2\u5bdf',
                  content: result.strokeObservation,
                ),
              if (result.structureObservation.isNotEmpty)
                _AnalysisSection(
                  label: '\u7ed3\u6784\u89c2\u5bdf',
                  content: result.structureObservation,
                ),
              if (result.layoutObservation.isNotEmpty)
                _AnalysisSection(
                  label: '\u7ae0\u6cd5\u89c2\u5bdf',
                  content: result.layoutObservation,
                ),
              if (suggestions.isNotEmpty)
                _SuggestionSection(items: suggestions),
              const SizedBox(height: 4),
              Text(
                '保存后会同步更新课后练习建议，并把这次作品分析纳入学生 AI 洞察。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kPrimaryBlue,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: canApply && !_applying ? _handleApply : null,
                  icon: _applying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_note_outlined, size: 18),
                  label: Text(
                    _applying ? '\u5199\u5165\u4e2d...' : '写入建议并保存分析',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  final String label;
  final String content;

  const _AnalysisSection({required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = content.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
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
              value.isEmpty ? '\u672a\u8fd4\u56de\u5185\u5bb9\u3002' : value,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionSection extends StatelessWidget {
  final List<String> items;

  const _SuggestionSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
              '\u7ec3\u4e60\u5efa\u8bae',
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
