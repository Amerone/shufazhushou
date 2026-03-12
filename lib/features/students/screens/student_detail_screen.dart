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
    setState(() => _payments = list);
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    try {
      final dao = ref.read(attendanceDaoProvider);
      final batch = await dao.getByStudentPaged(
          widget.studentId, _pageSize, _page * _pageSize);
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

    final feeAsync = ref.watch(
      feeSummaryProvider(FeeSummaryParams(widget.studentId, from: from, to: to)),
    );
    final allTimeFeeAsync = ref.watch(
      feeSummaryProvider(FeeSummaryParams(widget.studentId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/students/${widget.studentId}/edit'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: theme.textTheme.titleLarge),
                    if (student.parentName != null) Text('家长：${student.parentName}'),
                    if (student.parentPhone != null) Text('电话：${student.parentPhone}'),
                    Text('单价：¥${student.pricePerClass.toStringAsFixed(0)}/节'),
                    Text('状态：${student.status == 'active' ? '在读' : '休学'}'),
                    if (student.note != null && student.note!.isNotEmpty) Text('备注：${student.note}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: feeAsync.when(
                  loading: () => const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('加载失败: $e'),
                  data: (fee) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('本月出勤费用', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _FeeItem('应收', fee.totalReceivable),
                            _FeeItem('已收', fee.totalReceived),
                            _FeeItem('余额', fee.balance,
                                color: fee.balance < 0
                                    ? kRed
                                    : fee.balance > 0
                                        ? kGreen
                                        : kInkSecondary),
                          ],
                        ),
                        allTimeFeeAsync.whenOrNull(
                          data: (allFee) {
                            final balanceColor = allFee.balance < 0
                                ? kRed
                                : allFee.balance > 0
                                    ? kGreen
                                    : kInkSecondary;
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  Text('累计余额', style: theme.textTheme.bodySmall),
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: '累计余额 = 全部已收 - 全部应收\n正数 = 预存款，负数 = 欠费',
                                    child: Icon(Icons.info_outline, size: 14, color: kInkSecondary),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '¥${allFee.balance.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontFamily: 'NotoSansSC',
                                      color: balanceColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ) ?? const SizedBox.shrink(),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ExportConfigScreen(studentId: widget.studentId),
                    ),
                    child: const Text('生成报告'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => PaymentBottomSheet(studentId: widget.studentId),
                      );
                      _loadPayments();
                    },
                    child: const Text('记录缴费'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('缴费记录', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('共 ${_payments.length} 笔', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (_payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无缴费记录'),
              )
            else
              ..._payments.map(
                (p) => ListTile(
                  title: Text('¥${p.amount.toStringAsFixed(2)}'),
                  subtitle: p.note != null && p.note!.isNotEmpty ? Text(p.note!) : null,
                  trailing: Text(p.paymentDate),
                  onLongPress: () async {
                    final ok = await AppToast.showConfirm(
                        context, '确认删除该笔缴费记录（¥${p.amount.toStringAsFixed(2)}）？');
                    if (!ok) return;
                    await ref.read(paymentDaoProvider).delete(p.id);
                    invalidateAfterPaymentChange(ref);
                    _loadPayments();
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text('出勤记录', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_records.isEmpty && !_hasMore)
              const EmptyState(message: '暂无出勤记录')
            else
              ..._records.map(
                (r) => _AttendanceTile(
                  record: r,
                  onTap: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AttendanceEditSheet(record: r),
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
            if (_hasMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeeItem extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  const _FeeItem(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          '¥${value.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'NotoSansSC',
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  final Attendance record;
  final VoidCallback onTap;
  const _AttendanceTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = kStatusColor[record.status] ?? kInkSecondary;
    return ListTile(
      leading: Container(
        width: 4,
        height: 32,
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: Text('${record.date}  ${record.startTime}-${record.endTime}'),
      subtitle: record.note != null ? Text(record.note!) : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          kStatusLabel[record.status] ?? record.status,
          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      onTap: onTap,
    );
  }
}
