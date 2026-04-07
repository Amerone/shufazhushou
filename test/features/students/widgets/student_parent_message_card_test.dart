import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/student_parent_message_draft.dart';
import 'package:moyun/features/students/widgets/student_parent_message_card.dart';
import 'package:moyun/shared/theme.dart';

void main() {
  testWidgets('shows recommended template actions and supports switching', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1080, 2200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final copiedTexts = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments;
          if (args is Map && args['text'] is String) {
            copiedTexts.add(args['text'] as String);
          }
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudentParentMessageCard(
              draft: const StudentParentMessageDraft(
                usesAiInsight: true,
                readyLine: '这段时间孩子在结构稳定性上进步很明显。',
                attendanceLine: '最近两周都能按时到课。',
                observationLine: '最近一次课堂作品里，结构和行气都更稳了。',
                practiceLine: '回家可以继续练起收笔和中宫。',
                closingLine: '另外当前大约还剩 1.5 节课，也建议顺手确认下阶段排课。',
                shortText: '这段时间孩子在结构稳定性上进步很明显。 回家可以继续练起收笔和中宫。',
                fullText:
                    '家长您好，和您同步一下最近的课堂情况。\n这段时间孩子在结构稳定性上进步很明显。\n最近两周都能按时到课。\n最近一次课堂作品里，结构和行气都更稳了。\n回家可以继续练起收笔和中宫。\n另外当前大约还剩 1.5 节课，也建议顺手确认下阶段排课。',
                recommendedTemplateId: 'renewal',
                templates: [
                  StudentParentMessageTemplate(
                    id: 'progress',
                    label: '进步反馈',
                    channelLabel: '微信常用',
                    summary: '适合同步孩子最近的进步点。',
                    isRecommended: false,
                    shortText: '孩子最近在结构稳定性上进步很明显。',
                    fullText: '家长您好，和您同步一下孩子最近的课堂进步。',
                  ),
                  StudentParentMessageTemplate(
                    id: 'practice',
                    label: '练习提醒',
                    channelLabel: '课后提醒',
                    summary: '适合课后立即发。',
                    isRecommended: false,
                    shortText: '回家请继续练习起收笔和中宫。',
                    fullText: '家长您好，今天课后给您留一份简短练习提醒。',
                  ),
                  StudentParentMessageTemplate(
                    id: 'renewal',
                    label: '续费沟通',
                    channelLabel: '续费提醒',
                    summary: '适合课次接近用完时顺手沟通。',
                    isRecommended: true,
                    shortText: '另外当前大约还剩 1.5 节课，可以顺手确认下阶段排课。',
                    fullText: '家长您好，和您同步一下孩子最近的课堂情况，也顺手确认一下后续课次安排。',
                  ),
                ],
              ),
              onOpenPayment: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('家长沟通话术'), findsOneWidget);
    expect(find.text('当前建议'), findsOneWidget);
    expect(find.text('复制推荐微信整段'), findsOneWidget);
    expect(find.text('复制推荐短信'), findsOneWidget);
    expect(find.text('去记录缴费'), findsWidgets);

    await tester.tap(find.text('复制推荐微信整段'));
    await tester.pumpAndSettle();
    expect(copiedTexts.last, '家长您好，和您同步一下孩子最近的课堂情况，也顺手确认一下后续课次安排。');

    await tester.tap(find.text('练习提醒'));
    await tester.pumpAndSettle();
    expect(find.textContaining('练习起收笔和中宫'), findsOneWidget);

    final copyShortButton = find.widgetWithText(FilledButton, '复制短信短版');
    final copyShort = tester.widget<FilledButton>(copyShortButton);
    copyShort.onPressed!.call();
    await tester.pumpAndSettle();
    expect(copiedTexts.last, '回家请继续练习起收笔和中宫。');

    await tester.tap(find.text('切换到推荐'));
    await tester.pumpAndSettle();
    expect(find.text('续费沟通'), findsWidgets);
  });
}

void _noop() {}
