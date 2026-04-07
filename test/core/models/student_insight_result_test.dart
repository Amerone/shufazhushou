import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/student_insight_result.dart';

void main() {
  test('parses structured insight content from saved student note', () {
    final result = StudentInsightResult.fromSavedNote(
      rawText:
          '总体画像：课堂状态稳定，进入持续进步阶段\n'
          '上课规律：最近两周基本按时到课\n'
          '作品观察：结构更稳，行气更顺\n'
          '进步判断：近三次课堂里结构控制明显提升\n'
          '风险提醒：\n'
          '1. 请假后需要重新热身\n'
          '2. 节奏稳定性偶尔波动\n'
          '教学建议：\n'
          '1. 下节课先做控笔热身\n'
          '2. 继续巩固中宫\n'
          '3. 安排一组行气过渡练习\n'
          '家长沟通：这段时间孩子状态比较稳，可以继续按现在节奏推进。',
    );

    expect(result.isStructured, isTrue);
    expect(result.summary, '课堂状态稳定，进入持续进步阶段');
    expect(result.attendancePattern, '最近两周基本按时到课');
    expect(result.writingObservation, '结构更稳，行气更顺');
    expect(result.progressInsight, '近三次课堂里结构控制明显提升');
    expect(result.riskAlerts, containsAll(<String>['请假后需要重新热身', '节奏稳定性偶尔波动']));
    expect(
      result.teachingSuggestions,
      containsAll(<String>['下节课先做控笔热身', '继续巩固中宫', '安排一组行气过渡练习']),
    );
    expect(result.parentCommunicationTip, contains('状态比较稳'));
  });
}
