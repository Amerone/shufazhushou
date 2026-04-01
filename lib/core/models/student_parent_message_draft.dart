class StudentParentMessageTemplate {
  final String id;
  final String label;
  final String channelLabel;
  final String summary;
  final bool isRecommended;
  final String shortText;
  final String fullText;

  const StudentParentMessageTemplate({
    required this.id,
    required this.label,
    required this.channelLabel,
    required this.summary,
    required this.isRecommended,
    required this.shortText,
    required this.fullText,
  });
}

class StudentParentMessageDraft {
  final bool usesAiInsight;
  final String readyLine;
  final String attendanceLine;
  final String observationLine;
  final String practiceLine;
  final String closingLine;
  final String shortText;
  final String fullText;
  final String recommendedTemplateId;
  final List<StudentParentMessageTemplate> templates;

  const StudentParentMessageDraft({
    required this.usesAiInsight,
    required this.readyLine,
    required this.attendanceLine,
    required this.observationLine,
    required this.practiceLine,
    required this.closingLine,
    required this.shortText,
    required this.fullText,
    required this.recommendedTemplateId,
    required this.templates,
  });
}
