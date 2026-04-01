enum ExportTemplateId { parentMonthly, teacherDetailed, financeStatement }

extension ExportTemplateIdX on ExportTemplateId {
  String get settingValue {
    switch (this) {
      case ExportTemplateId.parentMonthly:
        return 'parent_monthly';
      case ExportTemplateId.teacherDetailed:
        return 'teacher_detailed';
      case ExportTemplateId.financeStatement:
        return 'finance_statement';
    }
  }

  String get label {
    switch (this) {
      case ExportTemplateId.parentMonthly:
        return '家长月报';
      case ExportTemplateId.teacherDetailed:
        return '教师详报';
      case ExportTemplateId.financeStatement:
        return '对账单';
    }
  }

  String get description {
    switch (this) {
      case ExportTemplateId.parentMonthly:
        return '突出余额、进步点和课后建议，适合发给家长。';
      case ExportTemplateId.teacherDetailed:
        return '保留完整课堂记录、费用与反馈，适合教学留档。';
      case ExportTemplateId.financeStatement:
        return '突出应收、已收与余额，适合月末对账。';
    }
  }
}

ExportTemplateId exportTemplateFromSetting(String? value) {
  for (final template in ExportTemplateId.values) {
    if (template.settingValue == value) {
      return template;
    }
  }
  return ExportTemplateId.parentMonthly;
}
