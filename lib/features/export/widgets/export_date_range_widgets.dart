import 'package:flutter/material.dart';

import '../../../shared/theme.dart';

class ExportDateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const ExportDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label，当前 $value',
      hint: '选择日期',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(value, style: const TextStyle(fontSize: 16)),
                ),
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: kInkSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExportDateRangeFields extends StatelessWidget {
  final String fromLabel;
  final String fromValue;
  final VoidCallback onFromTap;
  final String toLabel;
  final String toValue;
  final VoidCallback onToTap;

  const ExportDateRangeFields({
    super.key,
    required this.fromLabel,
    required this.fromValue,
    required this.onFromTap,
    required this.toLabel,
    required this.toValue,
    required this.onToTap,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final fieldWidth = width < 420 ? width : (width - 32) / 2;

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: fieldWidth,
                child: ExportDateField(
                  label: fromLabel,
                  value: fromValue,
                  onTap: onFromTap,
                ),
              ),
              if (width >= 420)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.arrow_forward_outlined,
                    size: 16,
                    color: kInkSecondary,
                  ),
                ),
              SizedBox(
                width: fieldWidth,
                child: ExportDateField(
                  label: toLabel,
                  value: toValue,
                  onTap: onToTap,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
