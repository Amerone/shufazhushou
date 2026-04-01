import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/attendance.dart';
import '../../../core/models/export_template.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/seal_config.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/services/ai_analysis_note_codec.dart';
import '../../../core/utils/excel_exporter.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/brush_stroke_divider.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';

class ExportConfigScreen extends ConsumerStatefulWidget {
  final String studentId;
  final ExportTemplateId? initialTemplate;

  const ExportConfigScreen({
    super.key,
    required this.studentId,
    this.initialTemplate,
  });

  @override
  ConsumerState<ExportConfigScreen> createState() => _ExportConfigScreenState();
}

class _ExportConfigScreenState extends ConsumerState<ExportConfigScreen> {
  static const _presetMessages = [
    '\u672c\u6708\u8fdb\u6b65\u660e\u663e\uff0c\u8bf7\u7ee7\u7eed\u4fdd\u6301\u3002',
    '\u8fd1\u671f\u72b6\u6001\u7a33\u5b9a\uff0c\u5efa\u8bae\u575a\u6301\u65e5\u5e38\u7ec3\u4e60\u3002',
    '\u57fa\u7840\u8d8a\u6765\u8d8a\u624e\u5b9e\uff0c\u53ef\u4ee5\u7ee7\u7eed\u6253\u78e8\u7ec6\u8282\u3002',
    '\u8bfe\u5802\u4e13\u6ce8\u5ea6\u5f88\u597d\uff0c\u7ee7\u7eed\u4fdd\u6301\u7ec3\u4e60\u8282\u594f\u3002',
  ];

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  final _msgCtrl = TextEditingController();
  bool _watermark = true;
  bool _includeAiAnalysis = false;
  bool _loading = false;
  Student? _latestStudentSnapshot;
  late ExportTemplateId _template;

  String _fmt(DateTime date) => formatDate(date);

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).valueOrNull ?? {};
    _msgCtrl.text = settings['default_message_template'] ?? '';
    _watermark = settings['default_watermark_enabled'] != 'false';
    _template =
        widget.initialTemplate ??
        exportTemplateFromSetting(settings['default_export_template']);
    unawaited(_refreshStudentSnapshot());
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Student? _findStudent() {
    final students = ref.read(studentProvider).valueOrNull ?? [];
    for (final item in students) {
      if (item.student.id == widget.studentId) {
        return item.student;
      }
    }
    return null;
  }

  Future<Student?> _loadStudent() async {
    final latest = await ref.read(studentDaoProvider).getById(widget.studentId);
    if (latest != null) return latest;
    return _findStudent();
  }

  Future<void> _refreshStudentSnapshot() async {
    final latest = await _loadStudent();
    if (!mounted || latest == null) return;
    setState(() {
      _latestStudentSnapshot = latest;
      if (_extractSavedAiAnalysis(latest.note) == null) {
        _includeAiAnalysis = false;
      }
    });
  }

  bool _validateRange() {
    if (_from.isAfter(_to)) {
      AppToast.showError(
        context,
        '\u5f00\u59cb\u65e5\u671f\u4e0d\u80fd\u665a\u4e8e\u7ed3\u675f\u65e5\u671f\u3002',
      );
      return false;
    }
    return true;
  }

  Future<_ExportData> _loadData() async {
    final from = _fmt(_from);
    final to = _fmt(_to);
    final recordsFuture = ref
        .read(attendanceDaoProvider)
        .getByStudentAndDateRange(widget.studentId, from, to);
    final paymentsFuture = ref
        .read(paymentDaoProvider)
        .getByStudentAndDateRange(widget.studentId, from, to);
    final records = await recordsFuture;
    final payments = await paymentsFuture;
    return _ExportData(records: records, payments: payments);
  }

  Future<_PreparedPdf> _buildPdf() async {
    final dataFuture = _loadData();
    final studentFuture = _loadStudent();
    final data = await dataFuture;
    final student = await studentFuture;
    if (student == null) {
      throw Exception(
        '\u672a\u627e\u5230\u5b66\u751f\uff0c\u8bf7\u8fd4\u56de\u540e\u91cd\u8bd5\u3002',
      );
    }
    final settings = ref.read(settingsProvider).valueOrNull ?? {};
    final savedAiAnalysis = _extractSavedAiAnalysis(student.note);
    final aiAnalysis = _includeAiAnalysis && savedAiAnalysis != null
        ? savedAiAnalysis
        : null;

    final path = await PdfGenerator.generate(
      student: student,
      from: _fmt(_from),
      to: _fmt(_to),
      records: data.records,
      payments: data.payments,
      teacherName: settings['teacher_name'] ?? kDefaultTeacherName,
      signaturePath: settings['signature_path'],
      message: _msgCtrl.text.trim(),
      watermark: _watermark,
      sealConfig: SealConfig.fromSettings(settings),
      aiAnalysis: aiAnalysis,
      template: _template,
    );
    return _PreparedPdf(path: path, student: student);
  }

  String? _extractSavedAiAnalysis(String? note) {
    return AiAnalysisNoteCodec.latestProgressContentForExport(note);
  }

  Future<bool> _shareFile(BuildContext feedbackContext, String path) async {
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
      return true;
    } catch (e) {
      if (feedbackContext.mounted) {
        AppToast.showError(feedbackContext, e.toString());
      }
      return false;
    }
  }

  Future<void> _previewPdf() async {
    if (!_validateRange()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final preparedPdf = await _buildPdf();
      final path = preparedPdf.path;
      final student = preparedPdf.student;

      if (mounted) {
        unawaited(InteractionFeedback.pageTurn(context));
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (previewCtx) => Scaffold(
              backgroundColor: Colors.transparent,
              body: InkWashBackground(
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 430;

                              final backButton = Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: kInkSecondary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: () =>
                                      Navigator.of(previewCtx).pop(),
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    size: 18,
                                  ),
                                  color: kPrimaryBlue,
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              );

                              final titleBlock = Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${student.name} \u62a5\u544a\u9884\u89c8',
                                      style: Theme.of(previewCtx)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_fmt(_from)} - ${_fmt(_to)}',
                                      style: Theme.of(
                                        previewCtx,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              );

                              final shareButton = OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  await InteractionFeedback.seal(previewCtx);
                                  if (!previewCtx.mounted) return;
                                  await _shareFile(previewCtx, path);
                                },
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 18,
                                ),
                                label: const Text('\u5206\u4eab'),
                              );

                              if (compact) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        backButton,
                                        const SizedBox(width: 14),
                                        titleBlock,
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    shareButton,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  backButton,
                                  const SizedBox(width: 14),
                                  titleBlock,
                                  const SizedBox(width: 12),
                                  shareButton,
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: GlassCard(
                            padding: const EdgeInsets.all(8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ColoredBox(
                                color: Colors.white,
                                child: PdfPreview(
                                  build: (_) async => File(path).readAsBytes(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sharePdf() async {
    if (!_validateRange()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final preparedPdf = await _buildPdf();
      if (!mounted) return;
      await InteractionFeedback.seal(context);
      if (!mounted) return;
      await _shareFile(context, preparedPdf.path);
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    if (!_validateRange()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final data = await _loadData();
      final student = await _loadStudent();
      if (student == null) {
        throw Exception(
          '\u672a\u627e\u5230\u5b66\u751f\uff0c\u8bf7\u8fd4\u56de\u540e\u91cd\u8bd5\u3002',
        );
      }
      final path = await ExcelExporter.export(
        student: student,
        from: _fmt(_from),
        to: _fmt(_to),
        records: data.records,
        payments: data.payments,
      );
      if (!mounted) return;
      final shared = await _shareFile(context, path);
      if (!shared) {
        return;
      }
      if (!mounted) return;
      await InteractionFeedback.seal(context);
      if (mounted) {
        AppToast.showSuccess(
          context,
          'Excel \u5df2\u751f\u6210\uff0c\u8bf7\u5728\u7cfb\u7edf\u5206\u4eab\u9762\u677f\u4e2d\u4fdd\u5b58\u3002',
        );
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleWatermark(bool value) async {
    if (!value) {
      final ok = await AppToast.showConfirm(
        context,
        '\u786e\u5b9a\u4e3a\u672c\u6b21\u5bfc\u51fa\u5173\u95ed\u6c34\u5370\u5417\uff1f',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    unawaited(InteractionFeedback.selection(context));
    setState(() => _watermark = value);
  }

  Future<void> _selectTemplate(ExportTemplateId template) async {
    if (!mounted || _template == template) return;
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    setState(() => _template = template);
    unawaited(
      ref
          .read(settingsProvider.notifier)
          .set('default_export_template', template.settingValue),
    );
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    onPicked(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final student = _latestStudentSnapshot ?? _findStudent();
    final rangeLabel = '${_fmt(_from)} - ${_fmt(_to)}';
    final rangeDays = _to.difference(_from).inDays + 1;
    final message = _msgCtrl.text.trim();
    final hasMessage = message.isNotEmpty;
    final messageLength = message.length;
    final savedAiAnalysis = _extractSavedAiAnalysis(student?.note);
    final hasSavedAiAnalysis = savedAiAnalysis != null;
    final includeAiAnalysis = _includeAiAnalysis && hasSavedAiAnalysis;
    final templateLabel = _template.label;
    final templateDescription = _template.description;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.zero,
        child: GlassCard(
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: bottomInset + MediaQuery.of(context).padding.bottom + 16,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kInkSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: kInkSecondary,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: kInkSecondary.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\u5bfc\u51fa\u5b66\u4e60\u62a5\u544a',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '\u53ef\u9884\u89c8 PDF\u3001\u76f4\u63a5\u5206\u4eab\uff0c\u6216\u5bfc\u51fa Excel \u8bb0\u5f55\u3002',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: kInkSecondary.withValues(alpha: 0.14),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    final metricWidth = compact
                        ? (constraints.maxWidth - 12) / 2
                        : (constraints.maxWidth - 36) / 4;

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
                                    '\u5bfc\u51fa\u6982\u89c8',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\u786e\u8ba4\u5bfc\u51fa\u5bf9\u8c61\u3001\u65e5\u671f\u8303\u56f4\u4e0e\u5bc4\u8bed\u540e\uff0c\u518d\u8fdb\u884c\u9884\u89c8\u6216\u5206\u4eab\u3002',
                                    style: theme.textTheme.bodySmall,
                                  ),
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
                              child: _ExportSummaryMetric(
                                icon: Icons.view_carousel_outlined,
                                label: '\u5bfc\u51fa\u6a21\u677f',
                                value: templateLabel,
                                color: kPrimaryBlue,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _ExportSummaryMetric(
                                icon: Icons.person_outline,
                                label: '\u5bfc\u51fa\u5bf9\u8c61',
                                value:
                                    student?.name ?? '\u5f53\u524d\u5b66\u751f',
                                color: kPrimaryBlue,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _ExportSummaryMetric(
                                icon: Icons.date_range_outlined,
                                label: '\u5bfc\u51fa\u8303\u56f4',
                                value: '$rangeDays\u5929',
                                color: kSealRed,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _ExportSummaryMetric(
                                icon: Icons.chat_bubble_outline,
                                label: '\u5bc4\u8bed',
                                value: hasMessage
                                    ? '$messageLength\u5b57'
                                    : '\u672a\u8bbe\u7f6e',
                                color: hasMessage ? kGreen : kOrange,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _ExportSummaryMetric(
                                icon: Icons.water_drop_outlined,
                                label: 'PDF \u6c34\u5370',
                                value: _watermark
                                    ? '\u5df2\u542f\u7528'
                                    : '\u5df2\u5173\u95ed',
                                color: _watermark
                                    ? kPrimaryBlue
                                    : kInkSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ExportMetaBadge(
                              icon: Icons.schedule_outlined,
                              label: rangeLabel,
                              color: kPrimaryBlue,
                            ),
                            _ExportMetaBadge(
                              icon: Icons.view_carousel_outlined,
                              label: templateLabel,
                              color: kPrimaryBlue,
                            ),
                            _ExportMetaBadge(
                              icon: Icons.picture_as_pdf_outlined,
                              label: _watermark
                                  ? '\u542b\u6c34\u5370 PDF'
                                  : '\u65e0\u6c34\u5370 PDF',
                              color: _watermark ? kSealRed : kInkSecondary,
                            ),
                            _ExportMetaBadge(
                              icon: Icons.psychology_alt_outlined,
                              label: includeAiAnalysis
                                  ? (hasSavedAiAnalysis
                                        ? '\u5305\u542b AI \u5206\u6790'
                                        : '\u6682\u65e0 AI \u5206\u6790')
                                  : '\u4e0d\u542b AI \u5206\u6790',
                              color: includeAiAnalysis
                                  ? (hasSavedAiAnalysis ? kGreen : kOrange)
                                  : kInkSecondary,
                            ),
                            const _ExportMetaBadge(
                              icon: Icons.approval_outlined,
                              label:
                                  '\u5370\u7ae0\u4e0e\u7b7e\u540d\u6837\u5f0f',
                              color: kSealRed,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _ExportSectionHeader(
                title: '\u5bfc\u51fa\u6a21\u677f',
                subtitle: templateDescription,
                trailing: templateLabel,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: kInkSecondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ExportTemplateId.values
                      .map(
                        (template) => ChoiceChip(
                          label: Text(template.label),
                          selected: _template == template,
                          onSelected: (_) => _selectTemplate(template),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 24),
              _ExportSectionHeader(
                title: '\u5bfc\u51fa\u8303\u56f4',
                subtitle:
                    '\u65e5\u671f\u8303\u56f4\u4f1a\u5f71\u54cd PDF \u9884\u89c8\u3001\u5206\u4eab\u548c Excel \u5bfc\u51fa\u3002',
                trailing: '$rangeDays\u5929',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: kInkSecondary.withValues(alpha: 0.12),
                  ),
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
                          child: _DateField(
                            label: '\u5f00\u59cb\u65e5\u671f',
                            value: _fmt(_from),
                            onTap: () => _pickDate(
                              initialDate: _from,
                              onPicked: (date) {
                                setState(() {
                                  _from = date;
                                  if (_to.isBefore(date)) {
                                    _to = date;
                                  }
                                });
                              },
                            ),
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
                          child: _DateField(
                            label: '\u7ed3\u675f\u65e5\u671f',
                            value: _fmt(_to),
                            onTap: () => _pickDate(
                              initialDate: _to,
                              onPicked: (date) {
                                setState(() {
                                  _to = date;
                                  if (_from.isAfter(date)) {
                                    _from = date;
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _ExportSectionHeader(
                title: '\u5bc4\u8bed\u5185\u5bb9',
                subtitle:
                    '\u663e\u793a\u5728 PDF \u7ed3\u5c3e\u9875\uff0c\u53ef\u901a\u8fc7\u9884\u8bbe\u5feb\u901f\u586b\u5145\u3002',
                trailing: hasMessage
                    ? '$messageLength / 200'
                    : '\u672a\u8bbe\u7f6e',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _msgCtrl,
                onChanged: (_) => setState(() {}),
                maxLength: 200,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '\u5bc4\u8bed',
                  counterText: '',
                  hintText:
                      '\u4f8b\u5982\uff1a\u672c\u6708\u8fdb\u6b65\u660e\u663e\uff0c\u8bf7\u7ee7\u7eed\u4fdd\u6301\u3002',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetMessages
                    .map(
                      (message) => ActionChip(
                        label: Text(
                          message,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                        side: BorderSide(
                          color: kInkSecondary.withValues(alpha: 0.2),
                        ),
                        onPressed: () {
                          unawaited(InteractionFeedback.selection(context));
                          _msgCtrl.text = message;
                          setState(() {});
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              _ExportSectionHeader(
                title: '\u5bfc\u51fa\u9009\u9879',
                subtitle:
                    '\u8fd9\u4e9b\u9009\u9879\u4f1a\u5f71\u54cd PDF \u7684\u5185\u5bb9\u4e0e\u6837\u5f0f\uff0cExcel \u5bfc\u51fa\u4e0d\u53d7\u5f71\u54cd\u3002',
                trailing: _watermark
                    ? '\u6c34\u5370\u5df2\u5f00\u542f'
                    : '\u6c34\u5370\u5df2\u5173\u95ed',
              ),
              const SizedBox(height: 12),
              _ExportSwitchTile(
                value: _watermark,
                icon: Icons.water_drop_outlined,
                title: '\u542f\u7528\u6c34\u5370',
                subtitle: _watermark
                    ? 'PDF \u5c06\u5305\u542b\u6c34\u5370\u4e0e\u5370\u7ae0\u3002'
                    : '\u5bfc\u51fa\u4e3a\u4e0d\u5e26\u6c34\u5370\u7684 PDF\u3002',
                onChanged: (value) {
                  _toggleWatermark(value);
                },
              ),
              const SizedBox(height: 12),
              _ExportSwitchTile(
                value: includeAiAnalysis,
                icon: Icons.psychology_alt_outlined,
                title: '\u5305\u542b AI \u5206\u6790',
                subtitle: hasSavedAiAnalysis
                    ? (includeAiAnalysis
                          ? '\u4f1a\u4ece\u5b66\u751f\u5907\u6ce8\u4e2d\u63d0\u53d6\u5df2\u4fdd\u5b58\u7684 AI \u5206\u6790\uff0c\u5e76\u63d2\u5165 PDF\u3002'
                          : '\u5173\u95ed\u540e\uff0cPDF \u4e0d\u4f1a\u5305\u542b AI \u5206\u6790\u9875\u3002')
                    : '\u6682\u65e0\u5df2\u4fdd\u5b58\u7684 AI \u5206\u6790\uff0c\u8bf7\u5148\u5728\u5b66\u751f\u8be6\u60c5\u9875\u4fdd\u5b58\u5206\u6790\u7ed3\u679c\u3002',
                enabled: hasSavedAiAnalysis,
                onChanged: (value) {
                  unawaited(InteractionFeedback.selection(context));
                  setState(() => _includeAiAnalysis = value);
                },
              ),
              const SizedBox(height: 24),
              _ExportSectionHeader(
                title: '\u5bfc\u51fa\u64cd\u4f5c',
                subtitle:
                    '\u53ef\u5148\u9884\u89c8 PDF\uff0c\u518d\u5206\u4eab\uff0c\u6216\u76f4\u63a5\u5bfc\u51fa Excel\u3002',
                trailing: _loading ? '\u5904\u7406\u4e2d' : '\u5c31\u7eea',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _ExportMetaBadge(
                    icon: Icons.preview_outlined,
                    label: 'PDF \u9884\u89c8',
                    color: kPrimaryBlue,
                  ),
                  _ExportMetaBadge(
                    icon: Icons.share_outlined,
                    label: '\u7cfb\u7edf\u5206\u4eab\u9762\u677f',
                    color: kSealRed,
                  ),
                  _ExportMetaBadge(
                    icon: Icons.table_view_outlined,
                    label: '\u540c\u65f6\u652f\u6301 Excel \u5bfc\u51fa',
                    color: kGreen,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final buttonWidth = width < 420 ? width : (width - 8) / 2;

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loading ? null : _previewPdf,
                          icon: const Icon(Icons.preview_outlined),
                          label: Text(
                            _loading
                                ? '\u5904\u7406\u4e2d...'
                                : '\u9884\u89c8 PDF',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loading ? null : _sharePdf,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('\u5206\u4eab PDF'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: kGreen.withValues(alpha: 0.5),
                            ),
                            foregroundColor: kGreen,
                          ),
                          onPressed: _loading ? null : _exportExcel,
                          icon: const Icon(Icons.table_view_outlined),
                          label: const Text('\u5bfc\u51fa Excel'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportData {
  final List<Attendance> records;
  final List<Payment> payments;

  const _ExportData({required this.records, required this.payments});
}

class _PreparedPdf {
  final String path;
  final Student student;

  const _PreparedPdf({required this.path, required this.student});
}

class _ExportSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;

  const _ExportSectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: trailing == null || compact
                  ? constraints.maxWidth
                  : constraints.maxWidth - 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  const BrushStrokeDivider(
                    width: 62,
                    height: 8,
                    color: kSealRed,
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: kInkSecondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(trailing!, style: theme.textTheme.bodySmall),
              ),
          ],
        );
      },
    );
  }
}

class _ExportSummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ExportSummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ExportMetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ExportMetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
            const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: kInkSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportSwitchTile extends StatelessWidget {
  final bool value;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _ExportSwitchTile({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: enabled ? 0.54 : 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final iconColor = enabled ? kPrimaryBlue : kInkSecondary;
          final titleStyle = theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: enabled ? null : kInkSecondary,
          );
          final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
            color: enabled ? null : kInkSecondary,
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: iconColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: titleStyle),
                              const SizedBox(height: 4),
                              Text(subtitle, style: subtitleStyle),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Switch(
                        value: value,
                        onChanged: enabled ? onChanged : null,
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: titleStyle),
                          const SizedBox(height: 4),
                          Text(subtitle, style: subtitleStyle),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(value: value, onChanged: enabled ? onChanged : null),
                  ],
                );
        },
      ),
    );
  }
}
