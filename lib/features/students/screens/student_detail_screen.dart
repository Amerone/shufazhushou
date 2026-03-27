import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/payment.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/attendance_edit_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../../export/screens/export_config_screen.dart';
import '../widgets/payment_bottom_sheet.dart';

class StudentDetailScreen extends ConsumerStatefulWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  List<Attendance> _records = [];
  List<Payment> _payments = [];
  int _page = 0;
  static const _pageSize = 20;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

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
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loadingMore) {
      _loadMore();
    }
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
          widget.studentId, _pageSize, _page * _pageSize);
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
    setState(() {
      _page = 0;
      _records = [];
      _hasMore = true;
      _loadingMore = false;
    });
    await Future.wait([_loadMore(), _loadPayments()]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final students = ref.watch(studentProvider).valueOrNull ?? [];
    final meta = students.where((m) => m.student.id == widget.studentId).firstOrNull;
    final student = meta?.student;

    if (student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final now = DateTime.now();
    final from = formatDate(DateTime(now.year, now.month, 1));
    final to = formatDate(DateTime(now.year, now.month + 1, 0));
    final statusText = student.status == 'active' ? '在读' : '休学';
    final statusColor = student.status == 'active' ? kGreen : kOrange;
    final lastAttendanceLabel = meta?.lastAttendanceDate ?? '暂无记录';
    final attendanceCountLabel = _hasMore ? '已加载 ${_records.length} 条' : '${_records.length} 条';
    final studentInitial = student.name.trim().isEmpty ? '学' : student.name.trim().substring(0, 1);

    final feeAsync = ref.watch(
      feeSummaryProvider(FeeSummaryParams(widget.studentId, from: from, to: to)),
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
              subtitle: '$statusText学员 · 课时单价 ¥${student.pricePerClass.toStringAsFixed(0)}',
              onBack: () => context.pop(),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/students/${widget.studentId}/edit'),
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
                              final metricColumns = constraints.maxWidth >= 720 ? 4 : 2;
                              final metricWidth =
                                  (constraints.maxWidth - 12 * (metricColumns - 1)) / metricColumns;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(18),
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
                                      SizedBox(
                                        width: compact ? constraints.maxWidth : constraints.maxWidth - 70,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  '学员档案概览',
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                _ProfileBadge(
                                                  icon: Icons.verified_user_outlined,
                                                  label: statusText,
                                                  color: statusColor,
                                                ),
                                                _ProfileBadge(
                                                  icon: Icons.payments_outlined,
                                                  label: '¥${student.pricePerClass.toStringAsFixed(0)}/节',
                                                  color: kPrimaryBlue,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '集中查看联系信息、最近上课情况和缴费动态，便于课后跟进。',
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
                                      if (student.parentName?.isNotEmpty ?? false)
                                        _InfoChip(
                                          icon: Icons.family_restroom_outlined,
                                          label: student.parentName!,
                                        ),
                                      if (student.parentPhone?.isNotEmpty ?? false)
                                        _InfoChip(
                                          icon: Icons.call_outlined,
                                          label: student.parentPhone!,
                                        ),
                                      _InfoChip(
                                        icon: Icons.history_toggle_off_outlined,
                                        label: '最近上课 $lastAttendanceLabel',
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
                                          label: '最近上课',
                                          value: lastAttendanceLabel,
                                          color: kPrimaryBlue,
                                          icon: Icons.event_available_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: metricWidth,
                                        child: _StudentSnapshot(
                                          label: '缴费记录',
                                          value: '${_payments.length} 笔',
                                          color: kGreen,
                                          icon: Icons.receipt_long_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: metricWidth,
                                        child: _StudentSnapshot(
                                          label: '出勤记录',
                                          value: attendanceCountLabel,
                                          color: kSealRed,
                                          icon: Icons.fact_check_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: metricWidth,
                                        child: _StudentSnapshot(
                                          label: '当前状态',
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
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: feeAsync.when(
                        loading: () => const SizedBox(
                          height: 88,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Text('加载失败：$e'),
                        data: (fee) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('费用概览', style: theme.textTheme.titleMedium),
                                  _ProfileBadge(
                                    icon: Icons.calendar_month_outlined,
                                    label: '$from 至 $to',
                                    color: kPrimaryBlue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '按本月区间汇总应收、已收和当前结余，便于核对学员收款情况。',
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
                                        child: _FeeMetric('本月应收', fee.totalReceivable, kPrimaryBlue),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _FeeMetric('本月已收', fee.totalReceived, kGreen),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _FeeMetric(
                                          '当前余额',
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
                                          final compact = constraints.maxWidth < 420;

                                          final label = Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('累计余额', style: theme.textTheme.bodySmall),
                                              const SizedBox(width: 4),
                                              const Tooltip(
                                                message: '累计余额 = 全部已收 - 全部应收\n正数表示预存，负数表示欠费',
                                                child: Icon(Icons.info_outline, size: 14, color: kInkSecondary),
                                              ),
                                            ],
                                          );

                                          final value = Text(
                                            '¥${allFee.balance.toStringAsFixed(2)}',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontFamily: 'NotoSansSC',
                                              color: balanceColor,
                                            ),
                                          );

                                          if (compact) {
                                            return Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: balanceColor.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  label,
                                                  const SizedBox(height: 8),
                                                  value,
                                                ],
                                              ),
                                            );
                                          }

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: balanceColor.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('快捷操作', style: theme.textTheme.titleMedium),
                              _ProfileBadge(
                                icon: Icons.flash_on_outlined,
                                label: '常用动作',
                                color: kSealRed,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '从这里快速生成报告或补录缴费，减少来回切换页面。',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              _ActionHintChip(
                                icon: Icons.description_outlined,
                                label: '支持 PDF 导出',
                              ),
                              _ActionHintChip(
                                icon: Icons.payments_outlined,
                                label: '保存后自动刷新余额',
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final buttonWidth = width < 420 ? width : (width - 10) / 2;

                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: buttonWidth,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      onPressed: () => showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) => ExportConfigScreen(studentId: widget.studentId),
                                      ),
                                      icon: const Icon(Icons.description_outlined),
                                      label: const Text('生成报告'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: buttonWidth,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      onPressed: () async {
                                        await showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => PaymentBottomSheet(studentId: widget.studentId),
                                        );
                                        _loadPayments();
                                      },
                                      icon: const Icon(Icons.payments_outlined),
                                      label: const Text('记录缴费'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionHeader(
                      title: '缴费记录',
                      subtitle: '用于核对学员余额和回顾每次收款备注。',
                      trailing: '共 ${_payments.length} 笔',
                    ),
                    const SizedBox(height: 10),
                    if (_payments.isEmpty)
                      const GlassCard(
                        padding: EdgeInsets.all(18),
                        child: EmptyState(message: '暂无缴费记录，可先从上方快捷操作中补录。'),
                      )
                    else
                      ..._payments.map(
                        (payment) => Padding(
                          padding: EdgeInsets.only(bottom: payment == _payments.last ? 0 : 10),
                          child: _PaymentCard(
                            payment: payment,
                            onDelete: () async {
                              final ok = await AppToast.showConfirm(
                                context,
                                '确认删除该笔缴费记录（¥${payment.amount.toStringAsFixed(2)}）？',
                              );
                              if (!ok) return;
                              await ref.read(paymentDaoProvider).delete(payment.id);
                              invalidateAfterPaymentChange(ref);
                              _loadPayments();
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    _SectionHeader(
                      title: '出勤记录',
                      subtitle: '点击单条记录可补充出勤状态、备注和课堂反馈。',
                      trailing: attendanceCountLabel,
                    ),
                    const SizedBox(height: 10),
                    if (_records.isEmpty && !_hasMore)
                      const GlassCard(
                        padding: EdgeInsets.all(18),
                        child: EmptyState(message: '暂无出勤记录，后续点名后会在这里持续累积。'),
                      )
                    else
                      ..._records.map(
                        (record) => Padding(
                          padding: EdgeInsets.only(bottom: record == _records.last ? 0 : 10),
                          child: _AttendanceCard(
                            record: record,
                            onTap: () async {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => AttendanceEditSheet(record: record),
                              );
                              setState(() {
                                _page = 0;
                                _records = [];
                                _hasMore = true;
                                _loadingMore = false;
                              });
                              _loadMore();
                            },
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
    );
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
        final contentWidth = compact ? constraints.maxWidth : constraints.maxWidth - 96;

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
                      style: theme.textTheme.bodySmall,
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
                border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
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

  const _DetailNoteCard({
    required this.note,
  });

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
            child: const Icon(Icons.sticky_note_2_outlined, size: 18, color: kPrimaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '备注',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: theme.textTheme.bodyMedium,
                ),
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

  const _InfoChip({
    required this.icon,
    required this.label,
  });

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

  const _ActionHintChip({
    required this.icon,
    required this.label,
  });

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
            '¥${value.toStringAsFixed(2)}',
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

  const _PaymentCard({
    required this.payment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final deleteAction = _DangerActionButton(
            tooltip: '删除缴费记录',
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
              '可删除',
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
                    const Icon(Icons.payments_outlined, color: kGreen, size: 18),
                    const SizedBox(height: 4),
                    Text(
                      '收款',
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
                            '¥${payment.amount.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '已收款',
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
                          label: '计入学员余额',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      payment.note?.isNotEmpty == true ? payment.note! : '这笔缴费会直接计入学员的累计余额。',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    if (compact)
                      Row(
                        children: [
                          actionHint,
                          const Spacer(),
                          deleteAction,
                        ],
                      ),
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

  const _AttendanceCard({
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColorValue = statusColor(record.status);
    final progressItems = _buildProgressItems(record);
    final startTime = parseTime(record.startTime);
    final endTime = parseTime(record.endTime);
    final minutes = (endTime.hour * 60 + endTime.minute) - (startTime.hour * 60 + startTime.minute);
    final durationLabel = minutes <= 0
        ? '时长待确认'
        : minutes < 60
            ? '$minutes 分钟'
            : minutes % 60 == 0
                ? '${minutes ~/ 60} 小时'
                : '${minutes ~/ 60} 小时 ${minutes % 60} 分钟';

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
              '点击编辑',
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
                  color: statusColorValue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_outlined, color: statusColorValue, size: 18),
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
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          label: '${record.startTime}-${record.endTime}',
                        ),
                        _DetailMetaChip(
                          icon: Icons.timelapse_outlined,
                          label: durationLabel,
                        ),
                        _DetailMetaChip(
                          icon: Icons.payments_outlined,
                          label: '¥${record.feeAmount.toStringAsFixed(2)}',
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
                        title: '课后练习',
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
                    if (compact) actionHint,
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                actionHint,
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

  const _DetailMetaChip({
    required this.icon,
    required this.label,
    this.color,
  });

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
    result.add('笔画 ${scores.strokeQuality!.toStringAsFixed(1)}');
  }
  if (scores.structureAccuracy != null) {
    result.add('结构 ${scores.structureAccuracy!.toStringAsFixed(1)}');
  }
  if (scores.rhythmConsistency != null) {
    result.add('节奏 ${scores.rhythmConsistency!.toStringAsFixed(1)}');
  }
  return result;
}

class _DangerActionButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const _DangerActionButton({
    required this.tooltip,
    required this.onPressed,
  });

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
