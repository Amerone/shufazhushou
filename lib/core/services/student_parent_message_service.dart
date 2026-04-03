import '../models/student.dart';
import '../models/student_artwork_timeline_entry.dart';
import '../models/student_parent_message_draft.dart';
import '../utils/fee_calculator.dart';
import 'ai_analysis_note_codec.dart';
import 'student_growth_summary_service.dart';

class StudentParentMessageService {
  const StudentParentMessageService();

  StudentParentMessageDraft build({
    required Student student,
    required StudentGrowthSummary growthSummary,
    required List<StudentArtworkTimelineEntry> artworkTimeline,
    double balance = 0,
    double pricePerClass = 0,
  }) {
    final latestInsightEntry = AiAnalysisNoteCodec.latestEntry(
      student.note,
      type: 'student_insight',
    );
    final latestInsight = _InsightSnapshot.fromNote(
      latestInsightEntry?.content,
    );
    final latestArtwork = artworkTimeline.isEmpty
        ? null
        : artworkTimeline.first;
    final insightIsFresh = _isInsightFresh(
      insightCreatedAt: latestInsightEntry?.createdAt,
      latestArtworkCreatedAt: latestArtwork?.createdAt,
      latestDataAt: growthSummary.latestDataAt,
    );
    final canUseInsight = latestInsight.hasUsefulContent && insightIsFresh;
    final focusLabel = _firstNonEmpty([
      latestArtwork?.focusTags.isNotEmpty == true
          ? latestArtwork!.focusTags.first
          : '',
      growthSummary.focusTags.isNotEmpty ? growthSummary.focusTags.first : '',
      '基本笔画和结构',
    ]);

    final readyLine = _ensureSentence(
      _firstNonEmpty([
        if (canUseInsight) latestInsight.parentCommunicationTip,
        _buildReadyLineFallback(student.name, latestArtwork, growthSummary),
      ]),
    );
    final attendanceLine = _ensureSentence(
      _buildAttendanceFallback(growthSummary),
    );
    final observationLine = _ensureSentence(
      _firstNonEmpty([
        if (canUseInsight) latestInsight.progressInsight,
        if (canUseInsight) latestInsight.writingObservation,
        _buildObservationFallback(latestArtwork, growthSummary),
      ]),
    );
    final practiceLine = _ensureSentence(
      _firstNonEmpty([
        _buildPracticeFromArtwork(latestArtwork),
        growthSummary.practiceSummary,
      ]),
    );
    final needsRenewalCue = _needsRenewalCue(
      balance: balance,
      pricePerClass: pricePerClass,
    );
    final recommendedTemplateId = _resolveRecommendedTemplateId(
      needsRenewalCue: needsRenewalCue,
      latestArtwork: latestArtwork,
    );
    final closingLine = _ensureSentence(
      _buildClosingLine(
        balance: balance,
        pricePerClass: pricePerClass,
        growthSummary: growthSummary,
        focusLabel: focusLabel,
      ),
    );

    final lines = <String>[
      '家长您好，和您同步一下${student.name}最近的课堂情况。',
      readyLine,
      attendanceLine,
      observationLine,
      practiceLine,
      closingLine,
    ].where((line) => line.trim().isNotEmpty).toList(growable: false);

    final shortText = <String>[
      readyLine,
      practiceLine,
    ].where((line) => line.trim().isNotEmpty).join(' ');
    final templates = _buildTemplates(
      studentName: student.name,
      readyLine: readyLine,
      attendanceLine: attendanceLine,
      observationLine: observationLine,
      practiceLine: practiceLine,
      closingLine: closingLine,
      needsRenewalCue: needsRenewalCue,
      recommendedTemplateId: recommendedTemplateId,
    );

    return StudentParentMessageDraft(
      usesAiInsight: canUseInsight,
      readyLine: readyLine,
      attendanceLine: attendanceLine,
      observationLine: observationLine,
      practiceLine: practiceLine,
      closingLine: closingLine,
      shortText: shortText,
      fullText: lines.join('\n'),
      recommendedTemplateId: recommendedTemplateId,
      templates: templates,
    );
  }

  bool _isInsightFresh({
    required DateTime? insightCreatedAt,
    required DateTime? latestArtworkCreatedAt,
    required DateTime? latestDataAt,
  }) {
    if (insightCreatedAt == null) {
      return false;
    }
    final freshnessAnchors = <DateTime>[];
    if (latestArtworkCreatedAt != null) {
      freshnessAnchors.add(latestArtworkCreatedAt);
    }
    if (latestDataAt != null) {
      freshnessAnchors.add(latestDataAt);
    }
    if (freshnessAnchors.isEmpty) {
      return true;
    }
    final latestSourceAt = freshnessAnchors.reduce(
      (current, candidate) => candidate.isAfter(current) ? candidate : current,
    );
    return !insightCreatedAt.isBefore(latestSourceAt);
  }

  String _buildReadyLineFallback(
    String studentName,
    StudentArtworkTimelineEntry? latestArtwork,
    StudentGrowthSummary growthSummary,
  ) {
    final summary = _firstNonEmpty([
      latestArtwork?.summary,
      growthSummary.progressPoint,
    ]);
    if (summary.isEmpty) {
      return '$studentName最近课堂状态稳定，可以继续按当前节奏推进。';
    }
    return '最近$studentName的课堂表现里，$summary';
  }

  String _buildAttendanceFallback(StudentGrowthSummary growthSummary) {
    if (growthSummary.nextLessonLabel.trim() == '待确认') {
      return '最近一次课堂是 ${growthSummary.latestLessonLabel}，目前正在安排下一次上课时间。';
    }
    return '最近一次课堂是 ${growthSummary.latestLessonLabel}，下一次课程安排在 ${growthSummary.nextLessonLabel}。';
  }

  String _buildObservationFallback(
    StudentArtworkTimelineEntry? latestArtwork,
    StudentGrowthSummary growthSummary,
  ) {
    if (latestArtwork != null) {
      final observation = _firstNonEmpty([
        latestArtwork.structureObservation,
        latestArtwork.strokeObservation,
        latestArtwork.layoutObservation,
        latestArtwork.summary,
      ]);
      if (observation.isNotEmpty) {
        return '结合最近一次课堂作品来看，$observation';
      }
    }
    return growthSummary.attentionPoint;
  }

  String _buildPracticeFromArtwork(StudentArtworkTimelineEntry? latestArtwork) {
    if (latestArtwork == null || latestArtwork.practiceSuggestions.isEmpty) {
      return '';
    }
    return latestArtwork.practiceSuggestions.take(2).join('；');
  }

  String _buildClosingLine({
    required double balance,
    required double pricePerClass,
    required StudentGrowthSummary growthSummary,
    required String focusLabel,
  }) {
    final ledger = StudentLedgerView(
      balance: balance,
      pricePerClass: pricePerClass,
      hasBalanceHistory: true,
    );
    if (ledger.needsPaymentAttention) {
      return '另外当前课次已超出 ¥${ledger.balance.abs().toStringAsFixed(2)}，可以和家长一并确认后续续费安排。';
    }

    final remainingLessons = ledger.remainingLessons;
    if (remainingLessons != null &&
        remainingLessons >= 0 &&
        remainingLessons < 2.5) {
      return '另外当前大约还剩 ${remainingLessons.toStringAsFixed(1)} 节课，也建议顺手和家长确认下阶段排课。';
    }

    if (growthSummary.nextLessonLabel.trim() != '待确认') {
      return '下节课我会继续围绕$focusLabel帮孩子把状态稳住。';
    }
    return '接下来我会继续围绕$focusLabel帮孩子把状态稳住。';
  }

  List<StudentParentMessageTemplate> _buildTemplates({
    required String studentName,
    required String readyLine,
    required String attendanceLine,
    required String observationLine,
    required String practiceLine,
    required String closingLine,
    required bool needsRenewalCue,
    required String recommendedTemplateId,
  }) {
    return <StudentParentMessageTemplate>[
      _buildTemplate(
        id: 'progress',
        label: '进步反馈',
        channelLabel: '微信常用',
        summary: '适合课后同步孩子最近的进步点，先建立家长对课堂成果的感知。',
        isRecommended: recommendedTemplateId == 'progress',
        introLine: '家长您好，和您同步一下孩子最近的课堂进步。',
        bodyLines: [readyLine, observationLine, attendanceLine, closingLine],
        shortLines: [readyLine, observationLine],
      ),
      _buildTemplate(
        id: 'practice',
        label: '练习提醒',
        channelLabel: '课后提醒',
        summary: '适合下课后立刻发，让家长知道回家怎么练、盯什么点。',
        isRecommended: recommendedTemplateId == 'practice',
        introLine: '家长您好，今天课后给您留一份简短练习提醒。',
        bodyLines: [readyLine, practiceLine, observationLine, closingLine],
        shortLines: [practiceLine, closingLine],
      ),
      _buildTemplate(
        id: 'renewal',
        label: needsRenewalCue ? '续费沟通' : '排课沟通',
        channelLabel: needsRenewalCue ? '续费提醒' : '排课安排',
        summary: needsRenewalCue
            ? '适合课次接近用完时顺手沟通续费，不需要老师再单独组织措辞。'
            : '适合提前和家长确认下一阶段排课，让沟通更自然。',
        isRecommended: recommendedTemplateId == 'renewal',
        introLine: needsRenewalCue
            ? '家长您好，和您同步一下孩子最近课堂情况，也顺手确认一下后续课次安排。'
            : '家长您好，提前和您同步一下孩子近期课堂情况，方便我们安排下一阶段课程。',
        bodyLines: [readyLine, observationLine, practiceLine, closingLine],
        shortLines: [readyLine, closingLine],
      ),
    ];
  }

  StudentParentMessageTemplate _buildTemplate({
    required String id,
    required String label,
    required String channelLabel,
    required String summary,
    required bool isRecommended,
    required String introLine,
    required List<String> bodyLines,
    required List<String> shortLines,
  }) {
    final fullText = _joinNonEmpty([introLine, ...bodyLines]);
    final shortText = _joinNonEmpty(shortLines, separator: ' ');

    return StudentParentMessageTemplate(
      id: id,
      label: label,
      channelLabel: channelLabel,
      summary: summary,
      isRecommended: isRecommended,
      shortText: shortText,
      fullText: fullText,
    );
  }

  String _resolveRecommendedTemplateId({
    required bool needsRenewalCue,
    required StudentArtworkTimelineEntry? latestArtwork,
  }) {
    if (needsRenewalCue) {
      return 'renewal';
    }
    if (latestArtwork?.practiceSuggestions.isNotEmpty ?? false) {
      return 'practice';
    }
    return 'progress';
  }

  bool _needsRenewalCue({
    required double balance,
    required double pricePerClass,
  }) {
    final ledger = StudentLedgerView(
      balance: balance,
      pricePerClass: pricePerClass,
      hasBalanceHistory: true,
    );
    if (ledger.needsPaymentAttention) {
      return true;
    }
    final remainingLessons = ledger.remainingLessons;
    return remainingLessons != null &&
        remainingLessons >= 0 &&
        remainingLessons < 2.5;
  }

  String _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      final normalized = (candidate ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  String _ensureSentence(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (RegExp(r'[。！？?]$').hasMatch(normalized)) {
      return normalized;
    }
    return '$normalized。';
  }

  String _joinNonEmpty(List<String?> lines, {String separator = '\n'}) {
    return lines
        .map((line) => (line ?? '').trim())
        .where((line) => line.isNotEmpty)
        .join(separator);
  }
}

class _InsightSnapshot {
  final String attendancePattern;
  final String writingObservation;
  final String progressInsight;
  final String parentCommunicationTip;

  const _InsightSnapshot({
    required this.attendancePattern,
    required this.writingObservation,
    required this.progressInsight,
    required this.parentCommunicationTip,
  });

  bool get hasUsefulContent =>
      attendancePattern.isNotEmpty ||
      writingObservation.isNotEmpty ||
      progressInsight.isNotEmpty ||
      parentCommunicationTip.isNotEmpty;

  factory _InsightSnapshot.fromNote(String? noteContent) {
    return _InsightSnapshot(
      attendancePattern: _extractLabeledValue(noteContent, '上课规律'),
      writingObservation: _extractLabeledValue(noteContent, '作品观察'),
      progressInsight: _extractLabeledValue(noteContent, '进步判断'),
      parentCommunicationTip: _extractLabeledValue(noteContent, '家长沟通'),
    );
  }

  static String _extractLabeledValue(String? content, String label) {
    final text = (content ?? '').trim();
    if (text.isEmpty) {
      return '';
    }

    final pattern = RegExp('^$label[：:]\\s*(.*)\$');
    for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      final match = pattern.firstMatch(line);
      if (match != null) {
        return (match.group(1) ?? '').trim();
      }
    }
    return '';
  }
}
