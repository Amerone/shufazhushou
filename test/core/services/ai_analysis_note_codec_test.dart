import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/ai_analysis_note_codec.dart';

void main() {
  group('AiAnalysisNoteCodec', () {
    test('appends and reads latest progress analysis entry', () {
      final note = AiAnalysisNoteCodec.appendProgressAnalysis(
        existingNote: 'manual note',
        analysisText: 'Overall: stable progress',
        analyzedAt: DateTime(2026, 3, 30, 9, 15),
      );

      expect(note, contains('[AI_ANALYSIS_START|progress|'));
      expect(
        AiAnalysisNoteCodec.latestContent(note, type: 'progress'),
        'Overall: stable progress',
      );
    });

    test('returns latest entry of matching type only', () {
      var note = AiAnalysisNoteCodec.appendEntry(
        null,
        type: 'business',
        analysisText: 'Business insight',
        createdAt: DateTime(2026, 3, 30, 8, 0),
      );
      note = AiAnalysisNoteCodec.appendProgressAnalysis(
        existingNote: note,
        analysisText: 'Student progress',
        analyzedAt: DateTime(2026, 3, 30, 10, 0),
      );

      expect(AiAnalysisNoteCodec.latestContent(note), 'Student progress');
      expect(
        AiAnalysisNoteCodec.latestContent(note, type: 'business'),
        'Business insight',
      );
    });

    test('ignores empty analysis text', () {
      expect(
        AiAnalysisNoteCodec.appendEntry(
          'existing note',
          type: 'progress',
          analysisText: '   ',
        ),
        'existing note',
      );
    });

    test(
      'strips legacy mojibake/abnormal title lines from structured progress notes',
      () {
        const legacyTitle = '\uFFFD\uFFFDAI \u5B66\u4E60\u5206\u6790 2026-03-30 09:15\uFFFD\uFFFD';
        const normalTitle = '\u3010AI \u5B66\u4E60\u5206\u6790 2026-03-31 10:00\u3011';

        final note = [
          '[AI_ANALYSIS_START|progress|2026-03-30T09:15:00.000]',
          legacyTitle,
          'Legacy body line',
          '[AI_ANALYSIS_END]',
          '',
          '[AI_ANALYSIS_START|progress|2026-03-31T10:00:00.000]',
          normalTitle,
          'Latest body line',
          '[AI_ANALYSIS_END]',
        ].join('\n');

        final entries = AiAnalysisNoteCodec.decodeEntries(note);
        expect(entries, hasLength(2));
        expect(entries.first.content, 'Legacy body line');
        expect(entries.last.content, 'Latest body line');
        expect(
          AiAnalysisNoteCodec.latestContent(note, type: 'progress'),
          'Latest body line',
        );
      },
    );

    test('falls back to legacy plain-text progress analysis blocks', () {
      const note = 'manual note\n\n'
          'AI \u5B66\u4E60\u5206\u6790\n'
          '\u603B\u4F53\u8BC4\u4EF7\uFF1A\u7A33\u6B65\u8FDB\u6B65\n'
          '\u8D8B\u52BF\u5206\u6790\uFF1A\u51FA\u52E4\u4E0E\u8BFE\u540E\u7EC3\u4E60\u66F4\u7A33\u5B9A\n'
          '\u6559\u5B66\u5EFA\u8BAE\uFF1A\n'
          '1. \u4FDD\u6301\u6BCF\u65E5\u57FA\u7840\u7EC3\u4E60';

      expect(
        AiAnalysisNoteCodec.latestProgressContentForExport(note),
        '\u603B\u4F53\u8BC4\u4EF7\uFF1A\u7A33\u6B65\u8FDB\u6B65\n'
        '\u8D8B\u52BF\u5206\u6790\uFF1A\u51FA\u52E4\u4E0E\u8BFE\u540E\u7EC3\u4E60\u66F4\u7A33\u5B9A\n'
        '\u6559\u5B66\u5EFA\u8BAE\uFF1A\n'
        '1. \u4FDD\u6301\u6BCF\u65E5\u57FA\u7840\u7EC3\u4E60',
      );
    });

    test('falls back to English legacy plain-text progress analysis blocks', () {
      const note = 'manual note\n\n'
          'AI Progress Analysis\n'
          'Overall: steady progress\n'
          'Trend: attendance and practice are more stable\n'
          'Teaching suggestions:\n'
          '1. Keep daily basic practice';

      expect(
        AiAnalysisNoteCodec.latestProgressContentForExport(note),
        'Overall: steady progress\n'
        'Trend: attendance and practice are more stable\n'
        'Teaching suggestions:\n'
        '1. Keep daily basic practice',
      );
    });

    test('prefers structured progress analysis over legacy plain-text blocks', () {
      final structured = AiAnalysisNoteCodec.appendProgressAnalysis(
        existingNote: 'AI \u5B66\u4E60\u5206\u6790\n'
            '\u603B\u4F53\u8BC4\u4EF7\uFF1A\u65E7\u7248\u5185\u5BB9',
        analysisText: '\u603B\u4F53\u8BC4\u4EF7\uFF1A\u7ED3\u6784\u5316\u5185\u5BB9',
        analyzedAt: DateTime(2026, 4, 1, 9, 0),
      );

      expect(
        AiAnalysisNoteCodec.latestProgressContentForExport(structured),
        '\u603B\u4F53\u8BC4\u4EF7\uFF1A\u7ED3\u6784\u5316\u5185\u5BB9',
      );
    });
  });
}
