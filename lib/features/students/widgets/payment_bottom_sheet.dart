import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/payment.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../shared/constants.dart' show formatDate;
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';

class PaymentBottomSheet extends ConsumerStatefulWidget {
  final String studentId;
  final String? studentName;
  final double? pricePerClass;

  const PaymentBottomSheet({
    super.key,
    required this.studentId,
    this.studentName,
    this.pricePerClass,
  });

  @override
  ConsumerState<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends ConsumerState<PaymentBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  void _applyQuickAmount(double amount) {
    final value = _formatAmount(amount);
    _amountCtrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  double? _parsedAmount() => double.tryParse(_amountCtrl.text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final payment = Payment(
        id: const Uuid().v4(),
        studentId: widget.studentId,
        amount: double.parse(_amountCtrl.text.trim()),
        paymentDate: formatDate(_date),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await ref.read(paymentDaoProvider).insert(payment);
      invalidateAfterPaymentChange(ref);

      if (!mounted) return;
      AppToast.showSuccess(context, '已记录缴费');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final pricePerClass = widget.pricePerClass;
    final enteredAmount = _parsedAmount();
    final feeSummaryAsync = ref.watch(
      feeSummaryProvider(FeeSummaryParams(widget.studentId)),
    );
    final quickAmounts = pricePerClass == null
        ? const <(String, double)>[]
        : <(String, double)>[
            ('1课 ¥${_formatAmount(pricePerClass)}', pricePerClass),
            ('2课 ¥${_formatAmount(pricePerClass * 2)}', pricePerClass * 2),
            ('4课 ¥${_formatAmount(pricePerClass * 4)}', pricePerClass * 4),
          ];

    final description = widget.studentName?.trim().isNotEmpty == true
        ? pricePerClass != null
              ? '当前学员：${widget.studentName}，单课时 ¥${_formatAmount(pricePerClass)}。保存后会自动刷新余额。'
              : '当前学员：${widget.studentName}。保存后会自动刷新余额。'
        : '录入本次收款金额和备注，保存后会自动刷新学员余额。';

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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: kInkSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '记录缴费',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                feeSummaryAsync.whenOrNull(
                      data: (summary) {
                        final currentLedger = StudentLedgerView.fromSummary(
                          summary,
                          pricePerClass: pricePerClass ?? 0,
                        );
                        final projectedBalance =
                            summary.balance + (enteredAmount ?? 0);
                        final projectedLedger = StudentLedgerView(
                          balance: projectedBalance,
                          pricePerClass: pricePerClass ?? 0,
                          hasBalanceHistory:
                              currentLedger.hasBalanceHistory ||
                              (enteredAmount ?? 0) > 0,
                        );

                        return Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kPrimaryBlue.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: kPrimaryBlue.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '缴费预览',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: kPrimaryBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _BalancePreviewRow(
                                label: '当前',
                                status: currentLedger.balanceStatusLabel,
                                amount: summary.balance,
                              ),
                              const SizedBox(height: 6),
                              _BalancePreviewRow(
                                label: '缴费后',
                                status: projectedLedger.balanceStatusLabel,
                                amount: projectedBalance,
                                emphasize: enteredAmount != null,
                              ),
                              if (pricePerClass != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '按单课时 ¥${_formatAmount(pricePerClass)} 估算，缴费后约 ${projectedLedger.remainingLessons?.toStringAsFixed(1) ?? '--'} 课。',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: kInkSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ) ??
                    const SizedBox.shrink(),
                if (quickAmounts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '按课时单价快速填充',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickAmounts
                        .map(
                          (item) => ActionChip(
                            label: Text(item.$1),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.56,
                            ),
                            side: BorderSide(
                              color: kInkSecondary.withValues(alpha: 0.14),
                            ),
                            onPressed: () {
                              unawaited(InteractionFeedback.selection(context));
                              _applyQuickAmount(item.$2);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: InputDecoration(
                    labelText: '缴费金额',
                    hintText: '例如：200',
                    prefixText: '¥ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.5),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入缴费金额';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return '请输入有效的正数金额';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '缴费日期',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(formatDate(_date))),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: '备注',
                    hintText: '可填写收款说明、优惠信息或转账渠道。',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_saving ? '保存中...' : '保存记录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalancePreviewRow extends StatelessWidget {
  final String label;
  final String status;
  final double amount;
  final bool emphasize;

  const _BalancePreviewRow({
    required this.label,
    required this.status,
    required this.amount,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = amount < 0
        ? kRed
        : amount > 0
        ? kGreen
        : kInkSecondary;

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            '$status ¥${amount.abs().toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
