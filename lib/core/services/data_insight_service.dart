import '../models/business_data_summary.dart';
import '../models/data_insight_result.dart';
import 'vision_analysis_gateway.dart';

class DataInsightService {
  final VisionAnalysisGateway gateway;

  const DataInsightService({required this.gateway});

  Future<DataInsightResult> analyzeBusinessData(
    BusinessDataSummary summary, {
    double temperature = 0.2,
  }) async {
    final result = await gateway.analyzeText(
      TextAnalysisRequest(
        prompt: buildPrompt(summary),
        temperature: temperature,
      ),
    );

    return DataInsightResult.fromVisionResult(
      model: result.model,
      rawText: result.text,
    );
  }

  static String buildPrompt(BusinessDataSummary summary) {
    final statusLines = summary.attendanceStatusDistribution.entries
        .map((entry) => '- ${_statusLabel(entry.key)}：${entry.value}')
        .toList(growable: false);
    final contributorLines = summary.topContributors
        .map(
          (item) =>
              '- ${item.name}：营收 ¥${item.totalFee.toStringAsFixed(2)}，出勤 ${item.attendanceCount} 次',
        )
        .toList(growable: false);
    final riskLines = summary.riskStudentNames
        .map((name) => '- $name')
        .toList(growable: false);
    final insightLines = summary.insightMessages
        .map((item) => '- $item')
        .toList(growable: false);

    final lines = <String>[
      '你是一位书法教培经营分析助手，请根据以下业务摘要输出简洁、可执行的经营洞察。',
      '统计周期：${summary.periodLabel}',
      '活跃学员：${summary.activeStudentCount} 人',
      '非活跃学员：${summary.inactiveStudentCount} 人',
      '周期营收：¥${summary.periodRevenue.toStringAsFixed(2)}',
      '',
      '出勤状态分布：',
      if (statusLines.isEmpty) '- 无数据' else ...statusLines,
      '',
      '学员贡献 Top：',
      if (contributorLines.isEmpty) '- 无数据' else ...contributorLines,
      '',
      '风险学员名单：',
      if (riskLines.isEmpty) '- 无数据' else ...riskLines,
      '',
      '当前经营提醒：',
      if (insightLines.isEmpty) '- 无数据' else ...insightLines,
      '',
      '请只输出一个 JSON 对象，不要添加 markdown 代码块，也不要输出额外说明。',
      'JSON 结构如下：',
      '{',
      '  "summary": "经营概况（1-2句）",',
      '  "revenue_insight": "营收洞察",',
      '  "engagement_insight": "学员活跃度分析",',
      '  "risk_alerts": ["风险提醒1", "风险提醒2"],',
      '  "recommendations": ["经营建议1", "经营建议2", "经营建议3"]',
      '}',
      '要求：',
      '- 所有字段都使用中文。',
      '- 无法判断时返回保守结论，不要编造。',
      '- recommendations 固定返回 3 条，且要具体可执行。',
      '- 结合给定数据分析，不要重复抄写原始输入。',
    ];

    return lines.join('\n');
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return '出勤';
      case 'late':
        return '迟到';
      case 'leave':
        return '请假';
      case 'absent':
        return '缺勤';
      case 'trial':
        return '试听';
      default:
        return status;
    }
  }
}
