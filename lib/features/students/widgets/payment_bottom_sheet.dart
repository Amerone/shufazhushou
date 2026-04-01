import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/dao/student_dao.dart';
import '../../../core/models/payment.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/constants.dart' show formatDate;
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';

class PaymentBottomSheet extends ConsumerStatefulWidget {
  final String studentId;
  final String? studentName;

  const PaymentBottomSheet({
    super.key,
    required this.studentId,
    this.studentName,
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
    final students = ref.watch(studentProvider).valueOrNull ?? const [];
    StudentWithMeta? currentStudent;
    for (final item in students) {
      if (item.student.id == widget.studentId) {
        currentStudent = item;
        break;
      }
    }
    final pricePerClass = currentStudent?.student.pricePerClass;
    final quickAmounts = pricePerClass == null
        ? const <(String, double)>[]
        : <(String, double)>[
            ('1节 ¥${_formatAmount(pricePerClass)}', pricePerClass),
            ('2节 ¥${_formatAmount(pricePerClass * 2)}', pricePerClass * 2),
            ('4节 ¥${_formatAmount(pricePerClass * 4)}', pricePerClass * 4),
          ];

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
                  widget.studentName?.trim().isNotEmpty == true
                      ? pricePerClass != null
                            ? '当前学员：${widget.studentName}，单节学费 ¥${_formatAmount(pricePerClass)}。保存后会自动刷新余额。'
                            : '当前学员：${widget.studentName}。保存后会自动刷新余额。'
                      : '录入本次收款金额和备注，保存后会自动刷新学员余额。',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (quickAmounts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '按课时单价快速填入',
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
                    hintText: '例如：600',
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
