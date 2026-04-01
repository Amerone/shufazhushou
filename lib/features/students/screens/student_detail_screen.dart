import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/export_template.dart';
import '../../../core/models/handwriting_analysis_result.dart';
import '../../../core/models/payment.dart';
import '../../../core/providers/ai_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/services/student_growth_summary_service.dart';
import '../../../core/services/handwriting_analysis_service.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/attendance_edit_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../../export/screens/export_config_screen.dart';
import '../widgets/attendance_ai_analysis_sheet.dart';
import '../widgets/payment_bottom_sheet.dart';
import '../widgets/student_ai_progress_card.dart';
import '../widgets/student_growth_workbench_card.dart';

enum _StudentDetailAnchor { finance, growth, actions, payments, attendance }

class StudentDetailScreen extends ConsumerStatefulWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentDetailScreen> createState() =>
      _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  List<Attendance> _records = [];
  List<Payment> _payments = [];
  int _page = 0;
  static const _pageSize = 20;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _showScrollToTop = false;
  final Set<String> _analyzingImageRecordIds = <String>{};
  final ScrollController _scrollController = ScrollController();
  final Map<_StudentDetailAnchor, GlobalKey> _sectionKeys = {
    for (final anchor in _StudentDetailAnchor.values) anchor: GlobalKey(),
  };
  _StudentDetailAnchor? _lastFocusedAnchor;

  @override
  void initState() {
    super.initState();
    Future(() => ref.read(studentProvider.notifier).reload());
    _loadMore();
    _loadPayments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showScrollToTop = _scrollController.hasClients
        ? _scrollController.offset > 280
        : false;
    if (showScrollToTop != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = showScrollToTop);
    }

    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _scrollToSection(_StudentDetailAnchor anchor) async {
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    final targetContext = _sectionKeys[anchor]?.currentContext;
    if (targetContext == null || !targetContext.mounted) return;
    setState(() => _lastFocusedAnchor = anchor);
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.06,
    );
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await InteractionFeedback.selection(context);
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadPayments() async {
    final dao = ref.read(paymentDaoProvider);
    final list = await dao.getByStudent(widget.studentId);
    if (!mounted) return;
    setState(() => _payments = list);
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    try {
      final dao = ref.read(attendanceDaoProvider);
      final batch = await dao.getByStudentPaged(
        widget.studentId,
        _pageSize,
        _page * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _records = [..._records, ...batch];
        _hasMore = batch.length == _pageSize;
        _page++;
      });
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _refresh() async {
    invalidateAfterAttendanceChange(ref);
    ref.invalidate(studentProvider);
    await Future.wait([_reloadAttendanceRecords(), _loadPayments()]);
  }

  Future<void> _reloadAttendanceRecords() async {
    if (!mounted) return;
    setState(() {
      _page = 0;
      _records = [];
      _hasMore = true;
      _loadingMore = false;
    });
    await _loadMore();
  }

  Future<void> _openExportSheet({ExportTemplateId? initialTemplate}) async {
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExportConfigScreen(
        studentId: widget.studentId,
        initialTemplate: initialTemplate,
      ),
    );
  }

  Future<void> _openPaymentSheet() async {
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentBottomSheet(studentId: widget.studentId),
    );
    invalidateAfterPaymentChange(ref);
    await _loadPayments();
  }

  Future<void> _openEditStudent() async {
    await InteractionFeedback.pageTurn(context);
    if (!mounted) return;
    context.push('/students/${widget.studentId}/edit');
  }

  Future<void> _analyzeAttendanceImage(
    Attendance record,
    String studentName,
  ) async {
    final service = ref.read(handwritingAnalysisServiceProvider);
    if (service == null) {
      AppToast.showError(
        context,
        '\u8bf7\u5148\u5728\u8bbe\u7f6e\u4e2d\u5b8c\u6210 AI \u914d\u7f6e\u3002',
      );
      return;
    }

    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _analyzingImageRecordIds.add(record.id));

    try {
      final result = await service.analyze(
        HandwritingAnalysisInput(
          imageSource: image.path,
          studentName: studentName,
        ),
      );
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => AttendanceAiAnalysisSheet(
          result: result,
          onApplySuggestion: () async {
            final nextPracticeNote = _buildPracticeSuggestionText(result);
            final applied = await _applyPracticeSuggestion(
              record,
              nextPracticeNote,
            );
            if (applied && sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(
        context,
        '\u56fe\u7247\u5206\u6790\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5\u3002',
      );
    } finally {
      if (mounted) {
        setState(() => _analyzingImageRecordIds.remove(record.id));
      }
    }
  }

  Future<bool> _applyPracticeSuggestion(
    Attendance record,
    String suggestion,
  ) async {
    final normalizedSuggestion = suggestion.trim();
    if (normalizedSuggestion.isEmpty) {
      AppToast.showError(
        context,
        'AI \u672a\u8fd4\u56de\u53ef\u5199\u5165\u7684\u7ec3\u4e60\u5efa\u8bae\u3002',
      );
      return false;
    }

    try {
      final attendanceDao = ref.read(attendanceDaoProvider);
      final latestRecord = await attendanceDao.getById(record.id);
      if (latestRecord == null) {
        if (mounted) {
          AppToast.showError(
            context,
            '\u672a\u627e\u5230\u5bf9\u5e94\u7684\u51fa\u52e4\u8bb0\u5f55\uff0c\u65e0\u6cd5\u66f4\u65b0\u7ec3\u4e60\u5efa\u8bae\u3002',
          );
        }
        return false;
      }

      final oldNote = latestRecord.homePracticeNote?.trim() ?? '';
      final stamp = formatDate(DateTime.now());
      final mergedNote = oldNote.isEmpty
          ? normalizedSuggestion
          : '$oldNote\n\nAI \u5efa\u8bae\u8bb0\u5f55\u4e8e $stamp\uff1a\n$normalizedSuggestion';

      final updated = latestRecord.copyWith(
        homePracticeNote: mergedNote,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await attendanceDao.update(updated);
      invalidateAfterAttendanceChange(ref);
      await _reloadAttendanceRecords();
      if (!mounted) return true;
      AppToast.showSuccess(
        context,
        '\u8bfe\u540e\u7ec3\u4e60\u5efa\u8bae\u5df2\u66f4\u65b0\u3002',
      );
      return true;
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          '\u66f4\u65b0\u8bfe\u540e\u7ec3\u4e60\u5efa\u8bae\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5\u3002',
        );
      }
      return false;
    }
  }

  String _buildPracticeSuggestionText(HandwritingAnalysisResult result) {
    final suggestions = result.practiceSuggestions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (suggestions.isNotEmpty) {
      return suggestions
          .asMap()
          .entries
          .map((entry) => '${entry.key + 1}. ${entry.value}')
          .join('\n');
    }

    final fallbackParts = <String>[
      result.summary.trim(),
      result.strokeObservation.trim(),
      result.structureObservation.trim(),
      result.layoutObservation.trim(),
    ].where((item) => item.isNotEmpty);

    return fallbackParts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewPaddingBottom = MediaQuery.of(context).viewPadding.bottom;
    final students = ref.watch(studentProvider).valueOrNull ?? [];
    final meta = students
        .where((m) => m.student.id == widget.studentId)
        .firstOrNull;
    final student = meta?.student;

    if (student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final now = DateTime.now();
    final from = formatDate(DateTime(now.year, now.month, 1));
    final to = formatDate(DateTime(now.year, now.month + 1, 0));
    final statusText = student.status == 'active'
        ? '\u5728\u8bfb'
        : '\u4f11\u5b66';
    final statusColor = student.status == 'active' ? kGreen : kOrange;
    final lastAttendanceLabel =
        meta?.lastAttendanceDate ?? '\u6682\u65e0\u8bb0\u5f55';
    final attendanceCountLabel = _hasMore
        ? '${_records.length}+ \u6761\u51fa\u52e4\u8bb0\u5f55'
        : '${_records.length} \u6761\u51fa\u52e4\u8bb0\u5f55';
    final studentInitial = student.name.trim().isEmpty
        ? '\u5b66'
        : student.name.trim().substring(0, 1);
    final growthSummary = const StudentGrowthSummaryService().build(
      records: _records,
      now: now,
    );

    final feeAsync = ref.watch(
      feeSummaryProvider(
        FeeSummaryParams(widget.studentId, from: from, to: to),
      ),
    );
    final allTimeFeeAsync = ref.watch(
      feeSummaryProvider(FeeSummaryParams(widget.studentId)),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: student.name,
              subtitle:
                  '$statusText \u00b7 \u8bfe\u65f6\u5355\u4ef7 \u00a5${student.pricePerClass.toStringAsFixed(0)}',
              onBack: () {
                unawaited(InteractionFeedback.pageTurn(context));
                context.pop();
              },
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: _openEditStudent,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 420;
                              final metricColumns = constraints.maxWidth >= 720
                                  ? 4
                                  : 2;
                              final metricWidth =
                                  (constraints.maxWidth -
                                      12 * (metricColumns - 1)) /
                                  metricColumns;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          studentInitial,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                color: statusColor,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: compact
                                            ? constraints.maxWidth
                                            : constraints.maxWidth - 70,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  '\u5b66\u751f\u6863\u6848\u6982\u89c8',
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                                _ProfileBadge(
                                                  icon: Icons
                                                      .verified_user_outlined,
                                                  label: statusText,
                                                  color: statusColor,
                                                ),
                                                _ProfileBadge(
                                                  icon: Icons.payments_outlined,
                                                  label:
                                                      '\u8bfe\u65f6\u5355\u4ef7 \u00a5${student.pricePerClass.toStringAsFixed(0)}',
                                                  color: kPrimaryBlue,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '\u5728\u8fd9\u91cc\u96c6\u4e2d\u67e5\u770b\u5bb6\u957f\u4fe1\u606f\u3001\u6700\u8fd1\u8bfe\u7a0b\u548c\u7f34\u8d39\u52a8\u6001\u3002',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      if (student.parentName?.isNotEmpty ??
                                          false)
                                        _InfoChip(
                                          icon: Icons.family_restroom_outlined,
                                          label: student.parentName!,
                                        ),
                                      if (student.parentPhone?.isNotEmpty ??
                                          false)
                                        _InfoChip(
                                          icon: Icons.call_outlined,
                                          label: student.parentPhone!,
                                        ),
                                      _InfoChip(
                                        icon: Icons.history_toggle_off_outlined,
                                        label:
                                            '\u6700\u8fd1\u51fa\u52e4\uff1a$lastAttendanceLabel',
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
                                        child: _StudentSnapshot(
                                          label: '\u6700\u8fd1\u8bfe\u7a0b',
                                          value: lastAttendanceLabel,
                                          color: kPrimaryBlue,
                                          icon: Icons.event_available_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: metricWidth,
                                        child: _StudentSnapshot(
                                          label: '\u7f34\u8d39\u8bb0\u5f55',
                                          value: '${_payments.length} \u6761',
                                          color: kGreen,
                                          icon: Icons.receipt_long_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: metricWidth,
                                        child: _StudentSnapshot(
                                          label: '\u51fa\u52e4\u8bb0\u5f55',
                                          value: attendanceCountLabel,
                                          color: kSealRed,
                                          icon: Icons.fact_check_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: metricWidth,
                                        child: _StudentSnapshot(
                                          label: '\u72b6\u6001',
                                          value: statusText,
                                          color: statusColor,
                                          icon: Icons.badge_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          if (student.note?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 16),
                            _DetailNoteCard(note: student.note!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StudentDetailQuickNavigator(
                      activeAnchor: _lastFocusedAnchor,
                      onTap: _scrollToSection,
                    ),
                    const SizedBox(height: 16),
                    _StudentSectionBlock(
                      anchorKey: _sectionKeys[_StudentDetailAnchor.finance],
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: feeAsync.when(
                          loading: () => const SizedBox(
                            height: 88,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Text(
                            '\u52a0\u8f7d\u8d39\u7528\u6c47\u603b\u5931\u8d25\uff1a$e',
                          ),
                          data: (fee) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '\u8d39\u7528\u6982\u89c8',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    _ProfileBadge(
                                      icon: Icons.calendar_month_outlined,
                                      label: '$from - $to',
                                      color: kPrimaryBlue,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '\u6309\u6708\u67e5\u770b\u5e94\u6536\u3001\u5df2\u6536\u548c\u5f53\u524d\u4f59\u989d\u3002',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;
                                    final itemWidth = width < 360
                                        ? width
                                        : width < 720
                                        ? (width - 12) / 2
                                        : (width - 24) / 3;

                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        SizedBox(
                                          width: itemWidth,
                                          child: _FeeMetric(
                                            '\u672c\u6708\u5e94\u6536',
                                            fee.totalReceivable,
                                            kPrimaryBlue,
                                          ),
                                        ),
                                        SizedBox(
                                          width: itemWidth,
                                          child: _FeeMetric(
                                            '\u672c\u6708\u5df2\u6536',
                                            fee.totalReceived,
                                            kGreen,
                                          ),
                                        ),
                                        SizedBox(
                                          width: itemWidth,
                                          child: _FeeMetric(
                                            '\u5f53\u524d\u4f59\u989d',
                                            fee.balance,
                                            fee.balance < 0
                                                ? kRed
                                                : fee.balance > 0
                                                ? kGreen
                                                : kInkSecondary,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                allTimeFeeAsync.whenOrNull(
                                      data: (allFee) {
                                        final balanceColor = allFee.balance < 0
                                            ? kRed
                                            : allFee.balance > 0
                                            ? kGreen
                                            : kInkSecondary;
                                        return LayoutBuilder(
                                          builder: (context, constraints) {
                                            final compact =
                                                constraints.maxWidth < 420;

                                            final label = Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '\u603b\u4f59\u989d',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                                const SizedBox(width: 4),
                                                const Tooltip(
                                                  message:
                                                      '\u603b\u4f59\u989d = \u7d2f\u8ba1\u5df2\u6536 - \u7d2f\u8ba1\u5e94\u6536\u3002\u6b63\u6570\u8868\u793a\u7ed3\u4f59\uff0c\u8d1f\u6570\u8868\u793a\u6b20\u8d39\u3002',
                                                  child: Icon(
                                                    Icons.info_outline,
                                                    size: 14,
                                                    color: kInkSecondary,
                                                  ),
                                                ),
                                              ],
                                            );

                                            final value = Text(
                                              '\u00a5${allFee.balance.toStringAsFixed(2)}',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontFamily: 'NotoSansSC',
                                                    color: balanceColor,
                                                  ),
                                            );

                                            if (compact) {
                                              return Container(
                                                padding: const EdgeInsets.all(
                                                  14,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: balanceColor
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    label,
                                                    const SizedBox(height: 8),
                                                    value,
                                                  ],
                                                ),
                                              );
                                            }

                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: balanceColor.withValues(
                                                  alpha: 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                children: [
                                                  label,
                                                  const Spacer(),
                                                  value,
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ) ??
                                    const SizedBox.shrink(),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StudentSectionBlock(
                      anchorKey: _sectionKeys[_StudentDetailAnchor.growth],
                      child: allTimeFeeAsync.when(
                        loading: () => const GlassCard(
                          padding: EdgeInsets.all(18),
                          child: SizedBox(
                            height: 72,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        error: (error, _) => GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Text('成长摘要加载失败：$error'),
                        ),
                        data: (allFee) {
                          return StudentGrowthWorkbenchCard(
                            summary: growthSummary,
                            balance: allFee.balance,
                            pricePerClass: student.pricePerClass,
                            onOpenReport: () => _openExportSheet(
                              initialTemplate: ExportTemplateId.parentMonthly,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StudentSectionBlock(
                      anchorKey: _sectionKeys[_StudentDetailAnchor.actions],
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '\u5feb\u901f\u64cd\u4f5c',
                                  style: theme.textTheme.titleMedium,
                                ),
                                _ProfileBadge(
                                  icon: Icons.flash_on_outlined,
                                  label: '\u5feb\u901f\u5165\u53e3',
                                  color: kSealRed,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '\u4e0d\u79bb\u5f00\u5f53\u524d\u9875\u5373\u53ef\u751f\u6210\u62a5\u544a\u6216\u8bb0\u5f55\u7f34\u8d39\u3002',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                _ActionHintChip(
                                  icon: Icons.description_outlined,
                                  label: '\u5bfc\u51fa PDF \u62a5\u544a',
                                ),
                                _ActionHintChip(
                                  icon: Icons.payments_outlined,
                                  label:
                                      '\u4fdd\u5b58\u540e\u81ea\u52a8\u5237\u65b0\u4f59\u989d',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final buttonWidth = width < 420
                                    ? width
                                    : (width - 10) / 2;

                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    SizedBox(
                                      width: buttonWidth,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        onPressed: _openExportSheet,
                                        icon: const Icon(
                                          Icons.description_outlined,
                                        ),
                                        label: const Text(
                                          '\u5bfc\u51fa\u62a5\u544a',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: buttonWidth,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        onPressed: _openPaymentSheet,
                                        icon: const Icon(
                                          Icons.payments_outlined,
                                        ),
                                        label: const Text(
                                          '\u65b0\u589e\u7f34\u8d39',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: buttonWidth,
                                      child: FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        onPressed: _openEditStudent,
                                        icon: const Icon(
                                          Icons.edit_note_outlined,
                                        ),
                                        label: const Text(
                                          '\u7f16\u8f91\u6863\u6848',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: buttonWidth,
                                      child: FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                        onPressed: () => _scrollToSection(
                                          _StudentDetailAnchor.attendance,
                                        ),
                                        icon: const Icon(
                                          Icons.fact_check_outlined,
                                        ),
                                        label: const Text(
                                          '\u8df3\u81f3\u51fa\u52e4',
                                        ),
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
                    const SizedBox(height: 16),
                    StudentAiProgressCard(student: student),
                    const SizedBox(height: 22),
                    _StudentSectionBlock(
                      anchorKey: _sectionKeys[_StudentDetailAnchor.payments],
                      child: Column(
                        children: [
                          _SectionHeader(
                            title: '\u7f34\u8d39\u8bb0\u5f55',
                            subtitle:
                                '\u67e5\u770b\u4f59\u989d\u53d8\u5316\u548c\u6bcf\u7b14\u7f34\u8d39\u5907\u6ce8\u3002',
                            trailing: '${_payments.length} \u6761',
                          ),
                          const SizedBox(height: 10),
                          if (_payments.isEmpty)
                            const GlassCard(
                              padding: EdgeInsets.all(18),
                              child: EmptyState(
                                message:
                                    '\u6682\u65f6\u8fd8\u6ca1\u6709\u7f34\u8d39\u8bb0\u5f55\u3002',
                              ),
                            )
                          else
                            ..._payments.map(
                              (payment) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: payment == _payments.last ? 0 : 10,
                                ),
                                child: _PaymentCard(
                                  payment: payment,
                                  onDelete: () async {
                                    final ok = await AppToast.showConfirm(
                                      context,
                                      '\u786e\u8ba4\u5220\u9664\u8fd9\u7b14\u7f34\u8d39\u8bb0\u5f55\u5417\uff1f\u91d1\u989d\u4e3a \u00a5${payment.amount.toStringAsFixed(2)}\u3002',
                                    );
                                    if (!ok) return;
                                    await ref
                                        .read(paymentDaoProvider)
                                        .delete(payment.id);
                                    invalidateAfterPaymentChange(ref);
                                    _loadPayments();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _StudentSectionBlock(
                      anchorKey: _sectionKeys[_StudentDetailAnchor.attendance],
                      child: Column(
                        children: [
                          KeyedSubtree(
                            key: _sectionKeys[_StudentDetailAnchor.attendance],
                            child: _SectionHeader(
                              title: '\u51fa\u52e4\u8bb0\u5f55',
                              subtitle:
                                  '\u70b9\u51fb\u8bb0\u5f55\u53ef\u7f16\u8f91\u51fa\u52e4\u72b6\u6001\u3001\u5907\u6ce8\u548c\u8bfe\u5802\u53cd\u9988\u3002',
                              trailing: attendanceCountLabel,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_records.isEmpty && !_hasMore)
                            const GlassCard(
                              padding: EdgeInsets.all(18),
                              child: EmptyState(
                                message:
                                    '\u6682\u65f6\u8fd8\u6ca1\u6709\u51fa\u52e4\u8bb0\u5f55\u3002',
                              ),
                            )
                          else
                            ..._records.map(
                              (record) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: record == _records.last ? 0 : 10,
                                ),
                                child: _AttendanceCard(
                                  record: record,
                                  analyzingImage: _analyzingImageRecordIds
                                      .contains(record.id),
                                  onAnalyzeImage: () => _analyzeAttendanceImage(
                                    record,
                                    student.name,
                                  ),
                                  onTap: () async {
                                    await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) =>
                                          AttendanceEditSheet(record: record),
                                    );
                                    await _reloadAttendanceRecords();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_hasMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _showScrollToTop ? Offset.zero : const Offset(0, 1.6),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _showScrollToTop ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_showScrollToTop,
            child: Padding(
              padding: EdgeInsets.only(bottom: viewPaddingBottom + 80),
              child: FloatingActionButton.small(
                heroTag: 'student-detail-scroll-top',
                onPressed: _scrollToTop,
                tooltip: '回到顶部',
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                foregroundColor: kPrimaryBlue,
                elevation: 0,
                child: const Icon(Icons.vertical_align_top_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentDetailQuickNavigator extends StatelessWidget {
  final _StudentDetailAnchor? activeAnchor;
  final ValueChanged<_StudentDetailAnchor> onTap;

  const _StudentDetailQuickNavigator({
    required this.activeAnchor,
    required this.onTap,
  });

  static const _items = [
    _StudentQuickNavItem(
      anchor: _StudentDetailAnchor.finance,
      icon: Icons.account_balance_wallet_outlined,
      label: '费用',
      color: kPrimaryBlue,
    ),
    _StudentQuickNavItem(
      anchor: _StudentDetailAnchor.growth,
      icon: Icons.auto_graph_outlined,
      label: '成长',
      color: kGreen,
    ),
    _StudentQuickNavItem(
      anchor: _StudentDetailAnchor.actions,
      icon: Icons.flash_on_outlined,
      label: '快捷',
      color: kSealRed,
    ),
    _StudentQuickNavItem(
      anchor: _StudentDetailAnchor.payments,
      icon: Icons.receipt_long_outlined,
      label: '缴费',
      color: kOrange,
    ),
    _StudentQuickNavItem(
      anchor: _StudentDetailAnchor.attendance,
      icon: Icons.fact_check_outlined,
      label: '出勤',
      color: kPrimaryBlue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '区块导航',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '档案速览',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kInkSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '直接跳到费用、成长、缴费或出勤区块，减少长页面中的来回滚动。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720
                  ? 4
                  : constraints.maxWidth >= 460
                  ? 3
                  : 2;
              final itemWidth =
                  (constraints.maxWidth - 10 * (columns - 1)) / columns;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in _items)
                    SizedBox(
                      width: itemWidth,
                      child: _StudentQuickNavChip(
                        item: item,
                        selected: activeAnchor == item.anchor,
                        onTap: () => onTap(item.anchor),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StudentQuickNavItem {
  final _StudentDetailAnchor anchor;
  final IconData icon;
  final String label;
  final Color color;

  const _StudentQuickNavItem({
    required this.anchor,
    required this.icon,
    required this.label,
    required this.color,
  });
}

class _StudentQuickNavChip extends StatelessWidget {
  final _StudentQuickNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _StudentQuickNavChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? item.color.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.color.withValues(alpha: selected ? 0.22 : 0.1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 18, color: item.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: item.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 16, color: item.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentSectionBlock extends StatelessWidget {
  final Key? anchorKey;
  final Widget child;

  const _StudentSectionBlock({this.anchorKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(key: anchorKey, child: child);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String trailing;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final contentWidth = compact
            ? constraints.maxWidth
            : constraints.maxWidth - 96;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: kInkSecondary.withValues(alpha: 0.12),
                ),
              ),
              child: Text(trailing, style: theme.textTheme.bodySmall),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ProfileBadge({
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

class _StudentSnapshot extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StudentSnapshot({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
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

class _DetailNoteCard extends StatelessWidget {
  final String note;

  const _DetailNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kPrimaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sticky_note_2_outlined,
              size: 18,
              color: kPrimaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u5907\u6ce8',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(note, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kInkSecondary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ActionHintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionHintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kPrimaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kPrimaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _FeeMetric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            '\u00a5${value.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'NotoSansSC',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Payment payment;
  final VoidCallback onDelete;

  const _PaymentCard({required this.payment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final deleteAction = _DangerActionButton(
            tooltip: '\u5220\u9664\u7f34\u8d39\u8bb0\u5f55',
            onPressed: onDelete,
          );

          final actionHint = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
            ),
            child: Text(
              '\u5220\u9664',
              style: theme.textTheme.bodySmall?.copyWith(
                color: kPrimaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: kGreen,
                      size: 18,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u5df2\u6536',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '\u00a5${payment.amount.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '\u5df2\u6536',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DetailMetaChip(
                          icon: Icons.calendar_today_outlined,
                          label: payment.paymentDate,
                        ),
                        _DetailMetaChip(
                          icon: Icons.receipt_long_outlined,
                          label: '\u5df2\u8ba1\u5165\u5b66\u751f\u4f59\u989d',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      payment.note?.isNotEmpty == true
                          ? payment.note!
                          : '\u8fd9\u7b14\u7f34\u8d39\u5df2\u8ba1\u5165\u5b66\u751f\u4f59\u989d\u3002',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    if (compact)
                      Row(children: [actionHint, const Spacer(), deleteAction]),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    actionHint,
                    const SizedBox(height: 10),
                    deleteAction,
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final Attendance record;
  final VoidCallback onTap;
  final VoidCallback onAnalyzeImage;
  final bool analyzingImage;

  const _AttendanceCard({
    required this.record,
    required this.onTap,
    required this.onAnalyzeImage,
    required this.analyzingImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColorValue = statusColor(record.status);
    final progressItems = _buildProgressItems(record);
    final startTime = parseTime(record.startTime);
    final endTime = parseTime(record.endTime);
    final minutes =
        (endTime.hour * 60 + endTime.minute) -
        (startTime.hour * 60 + startTime.minute);
    final durationLabel = minutes <= 0
        ? '\u65f6\u957f\u5f85\u5b9a'
        : minutes < 60
        ? '$minutes \u5206\u949f'
        : minutes % 60 == 0
        ? '${minutes ~/ 60} \u5c0f\u65f6'
        : '${minutes ~/ 60} \u5c0f\u65f6 ${minutes % 60} \u5206\u949f';

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final actionHint = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
            ),
            child: Text(
              '\u70b9\u51fb\u7f16\u8f91',
              style: theme.textTheme.bodySmall?.copyWith(
                color: kPrimaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
          final analysisAction = Container(
            decoration: BoxDecoration(
              color: kPrimaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: '\u5206\u6790\u5b57\u5e16\u56fe\u7247',
              onPressed: analyzingImage ? null : onAnalyzeImage,
              icon: analyzingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              color: kPrimaryBlue,
              visualDensity: VisualDensity.compact,
            ),
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: statusColorValue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: statusColorValue,
                      size: 18,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel(record.status),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColorValue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            record.date,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColorValue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel(record.status),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColorValue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DetailMetaChip(
                          icon: Icons.access_time_outlined,
                          label: '${record.startTime} - ${record.endTime}',
                        ),
                        _DetailMetaChip(
                          icon: Icons.timelapse_outlined,
                          label: durationLabel,
                        ),
                        _DetailMetaChip(
                          icon: Icons.payments_outlined,
                          label: '\u00a5${record.feeAmount.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                    if (record.note?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(record.note!, style: theme.textTheme.bodySmall),
                    ],
                    if (record.lessonFocusTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: record.lessonFocusTags
                            .map(
                              (tag) => _DetailMetaChip(
                                icon: Icons.auto_awesome_outlined,
                                label: tag,
                                color: kSealRed,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (record.homePracticeNote?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      _FeedbackBlock(
                        icon: Icons.edit_note_outlined,
                        title: '\u8bfe\u540e\u7ec3\u4e60',
                        content: record.homePracticeNote!,
                        color: kPrimaryBlue,
                      ),
                    ],
                    if (progressItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: progressItems
                            .map(
                              (item) => _DetailMetaChip(
                                icon: Icons.trending_up_outlined,
                                label: item,
                                color: kGreen,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (compact)
                      Row(
                        children: [actionHint, const Spacer(), analysisAction],
                      ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    analysisAction,
                    const SizedBox(height: 10),
                    actionHint,
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DetailMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _DetailMetaChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? kInkSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color == null
            ? Colors.white.withValues(alpha: 0.72)
            : resolvedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color == null
              ? kInkSecondary.withValues(alpha: 0.1)
              : resolvedColor.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color == null ? null : resolvedColor,
              fontWeight: color == null ? null : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _FeedbackBlock({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _buildProgressItems(Attendance record) {
  final scores = record.progressScores;
  if (scores == null || scores.isEmpty) return const <String>[];

  final result = <String>[];
  if (scores.strokeQuality != null) {
    result.add(
      '\u7b14\u753b\u8d28\u91cf\uff1a${scores.strokeQuality!.toStringAsFixed(1)}',
    );
  }
  if (scores.structureAccuracy != null) {
    result.add(
      '\u7ed3\u6784\u51c6\u786e\u5ea6\uff1a${scores.structureAccuracy!.toStringAsFixed(1)}',
    );
  }
  if (scores.rhythmConsistency != null) {
    result.add(
      '\u8282\u594f\u7a33\u5b9a\u6027\uff1a${scores.rhythmConsistency!.toStringAsFixed(1)}',
    );
  }
  return result;
}

class _DangerActionButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const _DangerActionButton({required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: const Icon(Icons.delete_outline),
        color: kRed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
