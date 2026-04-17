import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/export_template.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/services/student_artwork_timeline_service.dart';
import '../../../core/services/student_growth_summary_service.dart';
import '../../../core/services/student_parent_message_service.dart';
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
import '../widgets/attendance_artwork_analysis_launcher.dart';
import '../widgets/student_attendance_record_card.dart';
import '../widgets/student_artwork_timeline_card.dart';
import '../widgets/student_action_launcher.dart';
import '../widgets/student_ai_insight_card.dart';
import '../widgets/student_ai_progress_card.dart';
import '../widgets/student_finance_overview_card.dart';
import '../widgets/student_growth_workbench_card.dart';
import '../widgets/student_parent_message_card.dart';
import '../widgets/student_primary_actions_card.dart';

enum _StudentDetailAnchor { finance, payments, attendance }

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
  int _attendanceLoadGeneration = 0;
  final Set<String> _analyzingImageRecordIds = <String>{};
  final ScrollController _scrollController = ScrollController();
  final Map<_StudentDetailAnchor, GlobalKey> _sectionKeys = {
    for (final anchor in _StudentDetailAnchor.values) anchor: GlobalKey(),
  };

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

  Future<void> _loadMore({int? generation}) async {
    if (_loadingMore) return;
    final requestGeneration = generation ?? _attendanceLoadGeneration;
    final offset = _page * _pageSize;
    _loadingMore = true;
    try {
      final dao = ref.read(attendanceDaoProvider);
      final batch = await dao.getByStudentPaged(
        widget.studentId,
        _pageSize,
        offset,
      );
      if (!mounted || requestGeneration != _attendanceLoadGeneration) return;
      setState(() {
        _records = [..._records, ...batch];
        _hasMore = batch.length == _pageSize;
        _page++;
      });
    } finally {
      if (requestGeneration == _attendanceLoadGeneration) {
        _loadingMore = false;
      }
    }
  }

  Future<void> _refresh() async {
    invalidateAfterAttendanceChange(ref);
    ref.invalidate(studentProvider);
    await Future.wait([_reloadAttendanceRecords(), _loadPayments()]);
  }

  Future<void> _reloadAttendanceRecords() async {
    if (!mounted) return;
    final nextGeneration = _attendanceLoadGeneration + 1;
    _attendanceLoadGeneration = nextGeneration;
    setState(() {
      _page = 0;
      _records = [];
      _hasMore = true;
      _loadingMore = false;
    });
    await _loadMore(generation: nextGeneration);
  }

  Future<void> _openExportSheet({ExportTemplateId? initialTemplate}) async {
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    await showStudentExportSheet(
      context,
      studentId: widget.studentId,
      initialTemplate: initialTemplate,
    );
  }

  Future<void> _openPaymentSheet(Student student) async {
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    await showStudentPaymentSheet(
      context,
      studentId: student.id,
      studentName: student.name,
      pricePerClass: student.pricePerClass,
    );
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
    await launchAttendanceArtworkAnalysis(
      context,
      ref,
      record: record,
      studentName: studentName,
      onStarted: () {
        if (!mounted) return;
        setState(() => _analyzingImageRecordIds.add(record.id));
      },
      onFinished: () {
        if (!mounted) return;
        setState(() => _analyzingImageRecordIds.remove(record.id));
      },
      onAttendanceSaved: _reloadAttendanceRecords,
    );
  }

  Widget _buildDetailState({required Widget child}) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(child: Center(child: child)),
    );
  }

  Widget _buildMessageState({
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return _buildDetailState(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          child: EmptyState(
            message: message,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewPaddingBottom = MediaQuery.of(context).viewPadding.bottom;
    final studentsAsync = ref.watch(studentProvider);
    if (studentsAsync.hasError && !studentsAsync.hasValue) {
      return _buildMessageState(
        message:
            '\u5b66\u751f\u6863\u6848\u52a0\u8f7d\u5931\u8d25\uff1a${studentsAsync.error}',
        actionLabel: '\u8fd4\u56de\u5b66\u751f\u5217\u8868',
        onAction: () => context.go('/students'),
      );
    }
    final students = studentsAsync.valueOrNull;
    if (students == null) {
      return _buildDetailState(child: const CircularProgressIndicator());
    }
    final meta = students
        .where((m) => m.student.id == widget.studentId)
        .firstOrNull;
    final student = meta?.student;

    if (student == null) {
      return _buildMessageState(
        message:
            '\u8be5\u5b66\u751f\u6863\u6848\u4e0d\u5b58\u5728\u6216\u5df2\u88ab\u5220\u9664\u3002',
        actionLabel: '\u8fd4\u56de\u5b66\u751f\u5217\u8868',
        onAction: () => context.go('/students'),
      );
    }

    final now = DateTime.now();
    final from = formatDate(DateTime(now.year, now.month, 1));
    final to = formatDate(DateTime(now.year, now.month + 1, 0));
    final statusText = student.status == 'active'
        ? '\u5728\u8bfb'
        : '\u4f11\u5b66';
    final statusColor = student.status == 'active' ? kGreen : kOrange;
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
    final artworkTimeline = const StudentArtworkTimelineService().build(
      studentNote: student.note,
      records: _records,
    );

    final feeAsync = ref.watch(
      feeSummaryProvider(
        FeeSummaryParams(widget.studentId, from: from, to: to),
      ),
    );
    final allTimeFeeAsync = ref.watch(
      feeSummaryProvider(FeeSummaryParams(widget.studentId)),
    );
    final parentDraft = const StudentParentMessageService().build(
      student: student,
      growthSummary: growthSummary,
      artworkTimeline: artworkTimeline,
      balance: allTimeFeeAsync.valueOrNull?.balance ?? 0,
      pricePerClass: student.pricePerClass,
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
                    // 1. 费用概览
                    _StudentSectionBlock(
                      anchorKey: _sectionKeys[_StudentDetailAnchor.finance],
                      child: StudentFinanceOverviewCard(
                        student: student,
                        from: from,
                        to: to,
                        monthlyFeeAsync: feeAsync,
                        allTimeFeeAsync: allTimeFeeAsync,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 2. 学生资料与成长工作台
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              studentInitial,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        student.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    _ProfileBadge(
                                      icon: Icons.verified_user_outlined,
                                      label: statusText,
                                      color: statusColor,
                                    ),
                                  ],
                                ),
                                if ((student.parentName?.isNotEmpty ?? false) ||
                                    (student.parentPhone?.isNotEmpty ??
                                        false)) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
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
                                    ],
                                  ),
                                ],
                                if (student.note?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 10),
                                  _DetailNoteCard(note: student.note!),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    StudentPrimaryActionsCard(
                      onOpenPayment: () => _openPaymentSheet(student),
                      onOpenAttendance: () =>
                          _scrollToSection(_StudentDetailAnchor.attendance),
                      onOpenExport: _openExportSheet,
                      onEditStudent: _openEditStudent,
                    ),
                    const SizedBox(height: 22),
                    allTimeFeeAsync.when(
                      loading: () => const GlassCard(
                        padding: EdgeInsets.all(18),
                        child: SizedBox(
                          height: 72,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (error, _) => GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Text('加载成长与沟通摘要失败：$error'),
                      ),
                      data: (allFee) => StudentGrowthWorkbenchCard(
                        summary: growthSummary,
                        balance: allFee.balance,
                        pricePerClass: student.pricePerClass,
                        onOpenReport: () => _openExportSheet(
                          initialTemplate: ExportTemplateId.parentMonthly,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StudentParentMessageCard(
                      draft: parentDraft,
                      onOpenPayment: () {
                        _openPaymentSheet(student);
                      },
                    ),
                    const SizedBox(height: 16),
                    StudentArtworkTimelineCard(entries: artworkTimeline),
                    const SizedBox(height: 22),
                    // 3. 缴费记录
                    _StudentSectionBlock(
                      anchorKey: _sectionKeys[_StudentDetailAnchor.payments],
                      child: Column(
                        children: [
                          _SectionHeader(
                            title: '\u7f34\u8d39\u8bb0\u5f55',
                            trailing: '${_payments.length} \u6761',
                          ),
                          const SizedBox(height: 10),
                          if (_payments.isEmpty)
                            GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: EmptyState(
                                message:
                                    '\u6682\u65f6\u8fd8\u6ca1\u6709\u7f34\u8d39\u8bb0\u5f55\u3002',
                                actionLabel: '\u65b0\u589e\u7f34\u8d39',
                                onAction: () => _openPaymentSheet(student),
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
                    // 4. 出勤记录
                    _StudentSectionBlock(
                      anchorKey: _sectionKeys[_StudentDetailAnchor.attendance],
                      child: Column(
                        children: [
                          _SectionHeader(
                            title: '\u51fa\u52e4\u8bb0\u5f55',
                            subtitle:
                                '\u70b9\u51fb\u8bb0\u5f55\u53ef\u7f16\u8f91\u51fa\u52e4\u72b6\u6001\u3001\u5907\u6ce8\u548c\u8bfe\u5802\u53cd\u9988\u3002',
                            trailing: attendanceCountLabel,
                          ),
                          const SizedBox(height: 10),
                          if (_records.isEmpty && !_hasMore)
                            GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: EmptyState(
                                message:
                                    '\u6682\u65f6\u8fd8\u6ca1\u6709\u51fa\u52e4\u8bb0\u5f55\u3002',
                                actionLabel: '\u53bb\u9996\u9875\u8bb0\u8bfe',
                                onAction: () => context.go('/'),
                              ),
                            )
                          else
                            ..._records.map(
                              (record) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: record == _records.last ? 0 : 10,
                                ),
                                child: StudentAttendanceRecordCard(
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
                                      builder: (_) => AttendanceEditSheet(
                                        record: record,
                                        onAnalyzeArtwork: () =>
                                            _analyzeAttendanceImage(
                                              record,
                                              student.name,
                                            ),
                                      ),
                                    );
                                    await _reloadAttendanceRecords();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    // 5. AI 分析工具
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            14,
                            0,
                            14,
                            14,
                          ),
                          leading: Icon(
                            Icons.auto_awesome_outlined,
                            color: kSealRed.withValues(alpha: 0.7),
                            size: 20,
                          ),
                          title: Text(
                            'AI \u5206\u6790\u5de5\u5177',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          children: [
                            StudentAiInsightCard(student: student),
                            const SizedBox(height: 16),
                            StudentAiProgressCard(student: student),
                          ],
                        ),
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
                tooltip: '\u56de\u5230\u9876\u90e8',
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
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
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

class _DetailNoteCard extends StatelessWidget {
  final String note;

  const _DetailNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u5907\u6ce8',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(note),
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
                        if (compact) deleteAction,
                      ],
                    ),
                    const SizedBox(height: 8),
                    StudentDetailMetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: payment.paymentDate,
                    ),
                    if (payment.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(payment.note!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[const SizedBox(width: 10), deleteAction],
            ],
          );
        },
      ),
    );
  }
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
