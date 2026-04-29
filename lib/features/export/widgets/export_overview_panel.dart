import 'package:flutter/material.dart';

import '../../../shared/theme.dart';
import 'export_summary_widgets.dart';

class ExportOverviewPanel extends StatelessWidget {
  final String templateLabel;
  final String studentName;
  final int rangeDays;
  final String rangeLabel;
  final bool hasMessage;
  final int messageLength;
  final bool watermarkEnabled;
  final bool includeAiAnalysis;
  final bool hasSavedAiAnalysis;

  const ExportOverviewPanel({
    super.key,
    required this.templateLabel,
    required this.studentName,
    required this.rangeDays,
    required this.rangeLabel,
    required this.hasMessage,
    required this.messageLength,
    required this.watermarkEnabled,
    required this.includeAiAnalysis,
    required this.hasSavedAiAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final metricColumns = constraints.maxWidth < 360
              ? 1
              : compact
              ? 2
              : 4;
          final metricWidth =
              (constraints.maxWidth - 12 * (metricColumns - 1)) / metricColumns;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: compact
                        ? constraints.maxWidth
                        : constraints.maxWidth - 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '导出概览',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('检查对象、范围与寄语。', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: metricWidth,
                    child: ExportSummaryMetric(
                      icon: Icons.view_carousel_outlined,
                      label: '导出模板',
                      value: templateLabel,
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: ExportSummaryMetric(
                      icon: Icons.person_outline,
                      label: '导出对象',
                      value: studentName,
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: ExportSummaryMetric(
                      icon: Icons.date_range_outlined,
                      label: '导出范围',
                      value: '$rangeDays天',
                      color: kSealRed,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: ExportSummaryMetric(
                      icon: Icons.chat_bubble_outline,
                      label: '寄语',
                      value: hasMessage ? '$messageLength字' : '未设置',
                      color: hasMessage ? kGreen : kOrange,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: ExportSummaryMetric(
                      icon: Icons.water_drop_outlined,
                      label: 'PDF 水印',
                      value: watermarkEnabled ? '已启用' : '已关闭',
                      color: watermarkEnabled ? kPrimaryBlue : kInkSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ExportMetaBadge(
                    icon: Icons.schedule_outlined,
                    label: rangeLabel,
                    color: kPrimaryBlue,
                  ),
                  ExportMetaBadge(
                    icon: Icons.view_carousel_outlined,
                    label: templateLabel,
                    color: kPrimaryBlue,
                  ),
                  ExportMetaBadge(
                    icon: Icons.picture_as_pdf_outlined,
                    label: watermarkEnabled ? '含水印 PDF' : '无水印 PDF',
                    color: watermarkEnabled ? kSealRed : kInkSecondary,
                  ),
                  ExportMetaBadge(
                    icon: Icons.psychology_alt_outlined,
                    label: includeAiAnalysis
                        ? (hasSavedAiAnalysis ? '包含 AI 分析' : '暂无 AI 分析')
                        : '不含 AI 分析',
                    color: includeAiAnalysis
                        ? (hasSavedAiAnalysis ? kGreen : kOrange)
                        : kInkSecondary,
                  ),
                  const ExportMetaBadge(
                    icon: Icons.approval_outlined,
                    label: '印章与签名样式',
                    color: kSealRed,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
