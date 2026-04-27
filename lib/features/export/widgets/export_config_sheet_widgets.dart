import 'package:flutter/material.dart';

import '../../../core/models/export_template.dart';
import '../../../shared/theme.dart';

class ExportConfigSheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const ExportConfigSheetHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
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
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            button: true,
            label: '关闭导出配置',
            onTap: onClose,
            child: ExcludeSemantics(
              child: IconButton(
                tooltip: '关闭导出配置',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                color: kInkSecondary,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: kInkSecondary.withValues(alpha: 0.16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ExportTemplateSelector extends StatelessWidget {
  final ExportTemplateId selectedTemplate;
  final ValueChanged<ExportTemplateId> onSelected;

  const ExportTemplateSelector({
    super.key,
    required this.selectedTemplate,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ExportTemplateId.values
            .map(
              (template) => ChoiceChip(
                label: Text(template.label),
                selected: selectedTemplate == template,
                onSelected: (_) => onSelected(template),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
