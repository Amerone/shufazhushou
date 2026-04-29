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
import '../../../core/utils/fee_calculator.dart';
import '../../../core/utils/pdf_generator.dart';
import '../services/export_parent_snapshot_service.dart';
import '../services/export_temp_file_cleaner.dart';
import '../widgets/export_config_widgets.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';

const _sharedExportTempCleanupDelay = Duration(minutes: 10);

@visibleForTesting
Future<void> deleteExportTempFileForTesting(String path) =>
    deleteExportTempFile(path);

@visibleForTesting
Future<void> cleanupExportTempFileForShareForTesting(
  String path,
  ShareResultStatus status, {
  Duration deferredDelay = _sharedExportTempCleanupDelay,
}) => cleanupExportTempFileForShare(path, status, deferredDelay: deferredDelay);

@visibleForTesting
bool shouldTreatShareAsCompletedForTesting(ShareResultStatus status) =>
    shouldTreatShareAsCompleted(status);

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
  ExportActionType? _activeExportAction;
  Student? _latestStudentSnapshot;
  late ExportTemplateId _template;
  Future<ExportParentSnapshot>? _parentSnapshotFuture;
  String? _parentSnapshotKey;

  bool get _loading => _activeExportAction != null;

  String _fmt(DateTime date) => formatDate(date);

  String get _exportStatusLabel {
    return switch (_activeExportAction) {
      ExportActionType.previewPdf => 'PDF 预览中',
      ExportActionType.sharePdf => 'PDF 分享中',
      ExportActionType.exportExcel => 'Excel 导出中',
      null => '就绪',
    };
  }

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

  Future<StudentFeeSummary> _loadFeeSummary() {
    final from = _fmt(_from);
    final to = _fmt(_to);
    return FeeCalculator.calcSummary(
      widget.studentId,
      ref.read(attendanceDaoProvider),
      ref.read(paymentDaoProvider),
      from: from,
      to: to,
    );
  }

  Future<ExportParentSnapshot> _parentSnapshotFor(Student? student) {
    final key =
        '${widget.studentId}|${_fmt(_from)}|${_fmt(_to)}|'
        '${student?.updatedAt ?? 0}';
    if (_parentSnapshotKey != key || _parentSnapshotFuture == null) {
      _parentSnapshotKey = key;
      _parentSnapshotFuture = _loadParentSnapshot(student);
    }
    return _parentSnapshotFuture!;
  }

  Future<ExportParentSnapshot> _loadParentSnapshot(Student? student) async {
    final dataFuture = _loadData();
    final feeSummaryFuture = _loadFeeSummary();
    final resolvedStudent = student ?? await _loadStudent();
    final data = await dataFuture;
    final feeSummary = await feeSummaryFuture;
    return const ExportParentSnapshotService().buildSnapshot(
      records: data.records,
      feeSummary: feeSummary,
      pricePerClass: resolvedStudent?.pricePerClass ?? 0,
    );
  }

  Future<_PreparedPdf> _buildPdf() async {
    final dataFuture = _loadData();
    final studentFuture = _loadStudent();
    final feeSummaryFuture = _loadFeeSummary();
    final data = await dataFuture;
    final student = await studentFuture;
    final feeSummary = await feeSummaryFuture;
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
      feeSummary: feeSummary,
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

  bool _beginExport(ExportActionType action) {
    if (_loading || !_validateRange()) return false;
    FocusScope.of(context).unfocus();
    setState(() => _activeExportAction = action);
    return true;
  }

  void _endExport() {
    if (mounted) setState(() => _activeExportAction = null);
  }

  Future<ShareResult?> _shareFile(
    BuildContext feedbackContext,
    String path,
  ) async {
    try {
      return await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (e) {
      if (feedbackContext.mounted) {
        AppToast.showError(feedbackContext, e.toString());
      }
      return null;
    }
  }

  Future<void> _previewPdf() async {
    if (!_beginExport(ExportActionType.previewPdf)) return;
    String? tempPath;
    try {
      final preparedPdf = await _buildPdf();
      final path = preparedPdf.path;
      tempPath = path;
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
                                  tooltip: '返回',
                                  onPressed: () =>
                                      Navigator.of(previewCtx).pop(),
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    size: 18,
                                  ),
                                  color: kPrimaryBlue,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 44,
                                    height: 44,
                                  ),
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
      await deleteExportTempFile(tempPath);
      _endExport();
    }
  }

  Future<void> _sharePdf() async {
    if (!_beginExport(ExportActionType.sharePdf)) return;
    String? tempPath;
    try {
      final preparedPdf = await _buildPdf();
      tempPath = preparedPdf.path;
      if (!mounted) return;
      await InteractionFeedback.seal(context);
      if (!mounted) return;
      final shareResult = await _shareFile(context, preparedPdf.path);
      if (shareResult == null) {
        return;
      }
      await cleanupExportTempFileForShare(
        tempPath,
        shareResult.status,
        deferredDelay: _sharedExportTempCleanupDelay,
      );
      tempPath = null;
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      await deleteExportTempFile(tempPath);
      _endExport();
    }
  }

  Future<void> _exportExcel() async {
    if (!_beginExport(ExportActionType.exportExcel)) return;
    String? tempPath;
    try {
      final dataFuture = _loadData();
      final studentFuture = _loadStudent();
      final feeSummaryFuture = _loadFeeSummary();
      final data = await dataFuture;
      final student = await studentFuture;
      final feeSummary = await feeSummaryFuture;
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
        feeSummary: feeSummary,
      );
      tempPath = path;
      if (!mounted) return;
      final shareResult = await _shareFile(context, path);
      if (shareResult == null) {
        return;
      }
      await cleanupExportTempFileForShare(
        tempPath,
        shareResult.status,
        deferredDelay: _sharedExportTempCleanupDelay,
      );
      tempPath = null;
      if (!shouldTreatShareAsCompleted(shareResult.status)) {
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
      await deleteExportTempFile(tempPath);
      _endExport();
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
              ExportConfigSheetHeader(
                title: '\u5bfc\u51fa\u5b66\u4e60\u62a5\u544a',
                subtitle:
                    '\u53ef\u9884\u89c8 PDF\u3001\u76f4\u63a5\u5206\u4eab\uff0c\u6216\u5bfc\u51fa Excel \u8bb0\u5f55\u3002',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              ExportOverviewPanel(
                templateLabel: templateLabel,
                studentName: student?.name ?? '\u5f53\u524d\u5b66\u751f',
                rangeDays: rangeDays,
                rangeLabel: rangeLabel,
                hasMessage: hasMessage,
                messageLength: messageLength,
                watermarkEnabled: _watermark,
                includeAiAnalysis: includeAiAnalysis,
                hasSavedAiAnalysis: hasSavedAiAnalysis,
              ),
              const SizedBox(height: 24),
              ExportSectionHeader(
                title: '\u5bb6\u957f\u9996\u5c4f\u6458\u8981',
                subtitle:
                    '\u9884\u89c8\u5bb6\u957f\u6253\u5f00\u62a5\u544a\u65f6\u6700\u5148\u770b\u5230\u7684\u4fe1\u606f\uff0c\u4fbf\u4e8e\u5206\u4eab\u524d\u68c0\u67e5\u91cd\u70b9\u3002',
                trailing: '5 \u9879',
              ),
              const SizedBox(height: 12),
              ExportParentSnapshotCard(future: _parentSnapshotFor(student)),
              const SizedBox(height: 24),
              ExportSectionHeader(
                title: '\u5bfc\u51fa\u6a21\u677f',
                subtitle: templateDescription,
                trailing: templateLabel,
              ),
              const SizedBox(height: 12),
              ExportTemplateSelector(
                selectedTemplate: _template,
                onSelected: _selectTemplate,
              ),
              const SizedBox(height: 24),
              ExportSectionHeader(
                title: '\u5bfc\u51fa\u8303\u56f4',
                subtitle:
                    '\u65e5\u671f\u8303\u56f4\u4f1a\u5f71\u54cd PDF \u9884\u89c8\u3001\u5206\u4eab\u548c Excel \u5bfc\u51fa\u3002',
                trailing: '$rangeDays\u5929',
              ),
              const SizedBox(height: 12),
              ExportDateRangeFields(
                fromLabel: '\u5f00\u59cb\u65e5\u671f',
                fromValue: _fmt(_from),
                onFromTap: () => _pickDate(
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
                toLabel: '\u7ed3\u675f\u65e5\u671f',
                toValue: _fmt(_to),
                onToTap: () => _pickDate(
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
              const SizedBox(height: 24),
              ExportSectionHeader(
                title: '\u5bc4\u8bed\u5185\u5bb9',
                subtitle:
                    '\u663e\u793a\u5728 PDF \u7ed3\u5c3e\u9875\uff0c\u53ef\u901a\u8fc7\u9884\u8bbe\u5feb\u901f\u586b\u5145\u3002',
                trailing: hasMessage
                    ? '$messageLength / 200'
                    : '\u672a\u8bbe\u7f6e',
              ),
              const SizedBox(height: 12),
              ExportMessageSection(
                controller: _msgCtrl,
                onChanged: (_) => setState(() {}),
                labelText: '\u5bc4\u8bed',
                hintText:
                    '\u4f8b\u5982\uff1a\u672c\u6708\u8fdb\u6b65\u660e\u663e\uff0c\u8bf7\u7ee7\u7eed\u4fdd\u6301\u3002',
                presetMessages: _presetMessages,
                onPresetSelected: (message) {
                  unawaited(InteractionFeedback.selection(context));
                  _msgCtrl.text = message;
                  setState(() {});
                },
              ),
              const SizedBox(height: 24),
              ExportSectionHeader(
                title: '\u5bfc\u51fa\u9009\u9879',
                subtitle:
                    '\u8fd9\u4e9b\u9009\u9879\u4f1a\u5f71\u54cd PDF \u7684\u5185\u5bb9\u4e0e\u6837\u5f0f\uff0cExcel \u5bfc\u51fa\u4e0d\u53d7\u5f71\u54cd\u3002',
                trailing: _watermark
                    ? '\u6c34\u5370\u5df2\u5f00\u542f'
                    : '\u6c34\u5370\u5df2\u5173\u95ed',
              ),
              const SizedBox(height: 12),
              ExportSwitchTile(
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
              ExportSwitchTile(
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
              ExportSectionHeader(
                title: '\u5bfc\u51fa\u64cd\u4f5c',
                subtitle:
                    '\u53ef\u5148\u9884\u89c8 PDF\uff0c\u518d\u5206\u4eab\uff0c\u6216\u76f4\u63a5\u5bfc\u51fa Excel\u3002',
                trailing: _exportStatusLabel,
              ),
              const SizedBox(height: 12),
              ExportActionPanel(
                loading: _loading,
                activeAction: _activeExportAction,
                onPreview: _previewPdf,
                onSharePdf: _sharePdf,
                onExportExcel: _exportExcel,
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
