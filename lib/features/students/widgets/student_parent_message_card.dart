import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/student_parent_message_draft.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';

class StudentParentMessageCard extends StatefulWidget {
  final StudentParentMessageDraft draft;
  final VoidCallback? onOpenPayment;

  const StudentParentMessageCard({
    super.key,
    required this.draft,
    this.onOpenPayment,
  });

  @override
  State<StudentParentMessageCard> createState() =>
      _StudentParentMessageCardState();
}

class _StudentParentMessageCardState extends State<StudentParentMessageCard> {
  late String _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    _selectedTemplateId = widget.draft.recommendedTemplateId;
  }

  @override
  void didUpdateWidget(covariant StudentParentMessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.recommendedTemplateId !=
            widget.draft.recommendedTemplateId ||
        !_hasTemplate(_selectedTemplateId)) {
      _selectedTemplateId = widget.draft.recommendedTemplateId;
    }
  }

  bool _hasTemplate(String templateId) {
    for (final template in widget.draft.templates) {
      if (template.id == templateId) {
        return true;
      }
    }
    return false;
  }

  StudentParentMessageTemplate get _selectedTemplate {
    for (final template in widget.draft.templates) {
      if (template.id == _selectedTemplateId) {
        return template;
      }
    }
    return widget.draft.templates.first;
  }

  StudentParentMessageTemplate get _recommendedTemplate {
    for (final template in widget.draft.templates) {
      if (template.id == widget.draft.recommendedTemplateId) {
        return template;
      }
    }
    return _selectedTemplate;
  }

  Future<void> _copyText(String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppToast.showSuccess(context, successMessage);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.draft.templates.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('家长沟通话术', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '暂时还没有可用话术，请先补充课堂记录或生成 AI 洞察。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final selectedTemplate = _selectedTemplate;
    final recommendedTemplate = _recommendedTemplate;
    final showPaymentShortcut =
        widget.onOpenPayment != null && selectedTemplate.id == 'renewal';
    final showRecommendedPaymentShortcut =
        widget.onOpenPayment != null && recommendedTemplate.id == 'renewal';

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('家长沟通话术', style: theme.textTheme.titleMedium),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (widget.draft.usesAiInsight ? kGreen : kPrimaryBlue)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.draft.usesAiInsight ? '含 AI 洞察' : '按课堂数据整理',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.draft.usesAiInsight ? kGreen : kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '把课堂观察拆成多个常用沟通场景，老师按当前目的直接复制，不需要每次重新改口径。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
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
                      '当前建议',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _MetaBadge(
                      label: recommendedTemplate.label,
                      color: kPrimaryBlue,
                    ),
                    if (selectedTemplate.id != recommendedTemplate.id)
                      TextButton.icon(
                        onPressed: () {
                          setState(
                            () => _selectedTemplateId = recommendedTemplate.id,
                          );
                        },
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        label: const Text('切换到推荐'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  recommendedTemplate.summary,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          _copyText(recommendedTemplate.fullText, '推荐微信整段已复制'),
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: const Text('复制推荐微信整段'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _copyText(recommendedTemplate.shortText, '推荐短信短版已复制'),
                      icon: const Icon(Icons.textsms_outlined, size: 18),
                      label: const Text('复制推荐短信'),
                    ),
                    if (showRecommendedPaymentShortcut)
                      OutlinedButton.icon(
                        onPressed: widget.onOpenPayment,
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('去记录缴费'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.draft.templates
                .map(
                  (template) => _TemplateChip(
                    label: template.label,
                    selected: template.id == selectedTemplate.id,
                    recommended: template.isRecommended,
                    onTap: () {
                      setState(() => _selectedTemplateId = template.id);
                    },
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSealRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
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
                      selectedTemplate.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: kSealRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _MetaBadge(
                      label: selectedTemplate.channelLabel,
                      color: kSealRed,
                    ),
                    if (selectedTemplate.isRecommended)
                      const _MetaBadge(label: '当前推荐', color: kGreen),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  selectedTemplate.summary,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MessagePanel(
            title: '短信短版',
            hint: '适合快速提醒或当面转述',
            color: kPrimaryBlue,
            content: selectedTemplate.shortText,
          ),
          const SizedBox(height: 10),
          _MessagePanel(
            title: '微信整段版',
            hint: '适合直接复制发送给家长',
            color: kGreen,
            content: selectedTemplate.fullText,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 170,
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      _copyText(selectedTemplate.shortText, '短信短版已复制'),
                  icon: const Icon(Icons.textsms_outlined, size: 18),
                  label: const Text('复制短信短版'),
                ),
              ),
              SizedBox(
                width: 170,
                child: FilledButton.icon(
                  onPressed: () =>
                      _copyText(selectedTemplate.fullText, '微信整段已复制，可直接发给家长'),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('复制微信整段'),
                ),
              ),
              if (showPaymentShortcut)
                SizedBox(
                  width: 170,
                  child: OutlinedButton.icon(
                    onPressed: widget.onOpenPayment,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('去记录缴费'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.label,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? kSealRed : kInkSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? kSealRed.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? kSealRed.withValues(alpha: 0.26)
                : kInkSecondary.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (recommended) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '荐',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final String title;
  final String hint;
  final Color color;
  final String content;

  const _MessagePanel({
    required this.title,
    required this.hint,
    required this.color,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
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
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kInkSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
