import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/student.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';

class StudentFinanceOverviewCard extends StatelessWidget {
  final Student student;
  final String from;
  final String to;
  final AsyncValue<StudentFeeSummary> monthlyFeeAsync;
  final AsyncValue<StudentFeeSummary> allTimeFeeAsync;

  const StudentFinanceOverviewCard({
    super.key,
    required this.student,
    required this.from,
    required this.to,
    required this.monthlyFeeAsync,
    required this.allTimeFeeAsync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: monthlyFeeAsync.when(
        loading: () => const SizedBox(
          height: 88,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Text('加载费用汇总失败：$error'),
        data: (monthlyFee) {
          final monthlyLedger = StudentLedgerView.fromSummary(
            monthlyFee,
            pricePerClass: student.pricePerClass,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('费用概览', style: theme.textTheme.titleMedium),
                  _FinanceBadge(
                    icon: Icons.calendar_month_outlined,
                    label: '$from - $to',
                    color: kPrimaryBlue,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('按月查看应收、已收，余额会自动继承上月结转。', style: theme.textTheme.bodySmall),
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
                        child: _FinanceMetric(
                          '本月应收',
                          monthlyFee.totalReceivable,
                          kPrimaryBlue,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _FinanceMetric(
                          '本月已收',
                          monthlyFee.totalReceived,
                          kGreen,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _FinanceMetric(
                          monthlyLedger.currentBalanceLabel,
                          monthlyFee.balance,
                          _ledgerBalanceColor(monthlyLedger),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _FinanceBadge(
                    icon: Icons.history_toggle_off_outlined,
                    label:
                        '上月结转 ¥${monthlyFee.openingBalance.toStringAsFixed(2)}',
                    color: _ledgerAmountColor(monthlyFee.openingBalance),
                  ),
                  _FinanceBadge(
                    icon: Icons.sync_alt_outlined,
                    label:
                        '本月净变化 ¥${monthlyFee.periodNetChange.toStringAsFixed(2)}',
                    color: _ledgerAmountColor(monthlyFee.periodNetChange),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              allTimeFeeAsync.whenOrNull(
                    data: (allTimeFee) => _AllTimeBalanceBanner(
                      ledger: StudentLedgerView.fromSummary(
                        allTimeFee,
                        pricePerClass: student.pricePerClass,
                      ),
                      balance: allTimeFee.balance,
                    ),
                  ) ??
                  const SizedBox.shrink(),
            ],
          );
        },
      ),
    );
  }
}

class _FinanceBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FinanceBadge({
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

class _FinanceMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _FinanceMetric(this.label, this.value, this.color);

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

class _AllTimeBalanceBanner extends StatelessWidget {
  final StudentLedgerView ledger;
  final double balance;

  const _AllTimeBalanceBanner({required this.ledger, required this.balance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balanceColor = _ledgerBalanceColor(ledger);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final label = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ledger.totalBalanceLabel, style: theme.textTheme.bodySmall),
            const SizedBox(width: 4),
            const Tooltip(
              message: '总余额 = 累计已收 - 累计应收。正数表示结余，负数表示欠费。',
              child: Icon(Icons.info_outline, size: 14, color: kInkSecondary),
            ),
          ],
        );
        final value = Text(
          '¥${balance.toStringAsFixed(2)}',
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
              children: [label, const SizedBox(height: 8), value],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: balanceColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [label, const Spacer(), value]),
        );
      },
    );
  }
}

Color _ledgerAmountColor(double amount) {
  switch (resolveLedgerAmountState(amount)) {
    case LedgerAmountState.negative:
      return kRed;
    case LedgerAmountState.neutral:
      return kInkSecondary;
    case LedgerAmountState.positive:
      return kGreen;
  }
}

Color _ledgerBalanceColor(StudentLedgerView ledger) {
  switch (ledger.balanceState) {
    case LedgerBalanceState.debt:
      return kRed;
    case LedgerBalanceState.settled:
      return kInkSecondary;
    case LedgerBalanceState.surplus:
      return kGreen;
  }
}
