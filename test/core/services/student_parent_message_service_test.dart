import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/models/student_artwork_timeline_entry.dart';
import 'package:moyun/core/services/ai_analysis_note_codec.dart';
import 'package:moyun/core/services/student_growth_summary_service.dart';
import 'package:moyun/core/services/student_parent_message_service.dart';

void main() {
  const service = StudentParentMessageService();

  test(
    'prefers saved AI insight and recommends renewal template when balance is low',
    () {
      final student = Student(
        id: 'student-1',
        name: 'Alice',
        pricePerClass: 200,
        status: 'active',
        note: AiAnalysisNoteCodec.appendStudentInsight(
          existingNote: null,
          analysisText:
              '总体画像：课堂投入稳定\n'
              '上课规律：最近两周都能按时到课\n'
              '作品观察：结构更稳，行气更顺\n'
              '进步判断：近几次课堂里结构稳定性明显提升\n'
              '家长沟通：这段时间孩子在结构稳定性上进步很明显。',
          analyzedAt: DateTime(2026, 3, 30, 22, 0),
        ),
        createdAt: 1,
        updatedAt: 1,
      );

      final draft = service.build(
        student: student,
        growthSummary: const StudentGrowthSummary(
          progressPoint: '近3次评分持续提升：结构、节奏',
          attentionPoint: '下一阶段继续巩固章法节奏',
          practiceSummary: '每天临摹 15 分钟，重点检查中宫。',
          focusTags: ['结构', '章法'],
          latestLessonLabel: '2026-03-30',
          nextLessonLabel: '2026-04-06 18:00-19:30',
          latestProgressSummary: '结构 4.2 / 节奏 3.9',
          dataFreshness: '2026-03-30 21:00',
        ),
        artworkTimeline: [
          StudentArtworkTimelineEntry(
            createdAt: DateTime(2026, 3, 30, 21, 0),
            lessonDate: '2026-03-30',
            lessonTimeRange: '18:00-19:30',
            summary: '结构更稳，字形收得更集中',
            strokeObservation: '起收笔更利落',
            structureObservation: '左右留白更均衡',
            layoutObservation: '整行节奏更顺',
            practiceSuggestions: ['保持起收笔节奏', '继续检查中宫'],
            focusTags: ['结构', '章法'],
            progressLabel: '较上次更稳',
            scoreSummary: '笔画 3.8 / 结构 4.1',
          ),
        ],
        balance: 300,
        pricePerClass: 200,
      );

      expect(draft.usesAiInsight, isTrue);
      expect(draft.templates, hasLength(3));
      expect(draft.recommendedTemplateId, 'renewal');
      expect(draft.readyLine, contains('进步很明显'));
      expect(draft.attendanceLine, contains('最近一次课堂是 2026-03-30'));
      expect(draft.practiceLine, contains('保持起收笔节奏'));
      expect(draft.closingLine, contains('还剩 1.5 节课'));
      expect(
        draft.templates
            .firstWhere((template) => template.id == 'renewal')
            .label,
        '续费沟通',
      );
      expect(
        draft.templates
            .firstWhere((template) => template.id == 'renewal')
            .shortText,
        contains('还剩 1.5 节课'),
      );
      expect(draft.fullText, contains('家长您好'));
    },
  );

  test(
    'falls back to class data and recommends progress template by default',
    () {
      final draft = service.build(
        student: const Student(
          id: 'student-2',
          name: 'Bob',
          pricePerClass: 180,
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
        ),
        growthSummary: const StudentGrowthSummary(
          progressPoint: '最近一堂课里结构表现更稳',
          attentionPoint: '下一阶段继续巩固控笔稳定',
          practiceSummary: '每天控笔 10 分钟。',
          focusTags: ['控笔'],
          latestLessonLabel: '2026-03-29',
          nextLessonLabel: '待确认',
          latestProgressSummary: '笔画 3.5',
          dataFreshness: '2026-03-29 20:00',
        ),
        artworkTimeline: const [],
      );

      expect(draft.usesAiInsight, isFalse);
      expect(draft.templates, hasLength(3));
      expect(draft.recommendedTemplateId, 'progress');
      expect(draft.readyLine, contains('Bob'));
      expect(draft.attendanceLine, contains('最近一次课堂是 2026-03-29'));
      expect(draft.closingLine, contains('接下来我会继续围绕控笔'));
      expect(
        draft.templates
            .firstWhere((template) => template.id == 'renewal')
            .label,
        '排课沟通',
      );
    },
  );

  test('ignores stale AI insight when newer artwork data exists', () {
    final student = Student(
      id: 'student-3',
      name: 'Cici',
      pricePerClass: 180,
      status: 'active',
      note: AiAnalysisNoteCodec.appendStudentInsight(
        existingNote: null,
        analysisText:
            '总体画像：旧的总体判断\n'
            '上课规律：旧规律\n'
            '作品观察：旧观察\n'
            '进步判断：旧判断\n'
            '家长沟通：这是过期话术。',
        analyzedAt: DateTime(2026, 3, 20, 12, 0),
      ),
      createdAt: 1,
      updatedAt: 1,
    );

    final draft = service.build(
      student: student,
      growthSummary: const StudentGrowthSummary(
        progressPoint: '最近一堂课里结构表现更稳',
        attentionPoint: '下一阶段继续巩固控笔稳定',
        practiceSummary: '每天控笔 10 分钟。',
        focusTags: ['控笔'],
        latestLessonLabel: '2026-03-29',
        nextLessonLabel: '待确认',
        latestProgressSummary: '笔画 3.5',
        dataFreshness: '2026-03-29 20:00',
      ),
      artworkTimeline: [
        StudentArtworkTimelineEntry(
          createdAt: DateTime(2026, 3, 31, 21, 0),
          lessonDate: '2026-03-31',
          lessonTimeRange: '18:00-19:30',
          summary: '结构更稳，字形收得更集中',
          strokeObservation: '起收笔更利落',
          structureObservation: '左右留白更均衡',
          layoutObservation: '整行节奏更顺',
          practiceSuggestions: ['保持起收笔节奏'],
          focusTags: ['结构'],
          progressLabel: '较上次更稳',
          scoreSummary: '笔画 3.8 / 结构 4.1',
        ),
      ],
    );

    expect(draft.usesAiInsight, isFalse);
    expect(draft.readyLine, isNot(contains('过期话术')));
    expect(draft.observationLine, contains('左右留白更均衡'));
  });

  test(
    'ignores stale AI insight when newer class data exists without artwork',
    () {
      final student = Student(
        id: 'student-4',
        name: 'Dora',
        pricePerClass: 180,
        status: 'active',
        note: AiAnalysisNoteCodec.appendStudentInsight(
          existingNote: null,
          analysisText:
              '总体画像：old summary\n'
              '上课规律：old attendance\n'
              '作品观察：old observation\n'
              '进步判断：STALE_PROGRESS\n'
              '家长沟通：STALE_PARENT',
          analyzedAt: DateTime(2026, 3, 20, 12, 0),
        ),
        createdAt: 1,
        updatedAt: 1,
      );

      final draft = service.build(
        student: student,
        growthSummary: StudentGrowthSummary(
          progressPoint: 'FRESH_PROGRESS',
          attentionPoint: 'FRESH_ATTENTION',
          practiceSummary: 'FRESH_PRACTICE',
          focusTags: ['控笔'],
          latestLessonLabel: '2026-03-29',
          nextLessonLabel: '待确认',
          latestProgressSummary: 'fresh summary',
          dataFreshness: '2026-03-29 20:00',
          latestDataAt: DateTime(2026, 3, 29, 20, 0),
        ),
        artworkTimeline: const [],
      );

      expect(draft.usesAiInsight, isFalse);
      expect(draft.readyLine, isNot(contains('STALE_PARENT')));
      expect(draft.observationLine, isNot(contains('STALE_PROGRESS')));
      expect(draft.observationLine, contains('FRESH_ATTENTION'));
    },
  );
}
