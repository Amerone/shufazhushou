import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/attendance.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/seal_config.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/excel_exporter.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';

class ExportConfigScreen extends ConsumerStatefulWidget {
  final String studentId;

  const ExportConfigScreen({super.key, required this.studentId});

  @override
  ConsumerState<ExportConfigScreen> createState() => _ExportConfigScreenState();
}
class _ExportConfigScreenState extends ConsumerState<ExportConfigScreen> {
  static const _presetMessages = [
    '本月表现优秀，继续加油。',
    '进步明显，期待下一阶段更稳定的发挥。',
    '基础扎实，建议继续保持日常练习。',
    '笔法渐入佳境，保持这份专注。',
  ];

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  final _msgCtrl = TextEditingController();
  bool _watermark = true;
  bool _loading = false;

  String _fmt(DateTime date) => formatDate(date);

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).valueOrNull ?? {};
    _msgCtrl.text = settings['default_message_template'] ?? '';
    _watermark = settings['default_watermark_enabled'] != 'false';
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

  bool _validateRange() {
    if (_from.isAfter(_to)) {
      AppToast.showError(context, '开始日期不能晚于结束日期');
      return false;
    }
    return true;
  }

  Future<_ExportData> _loadData() async {
    final from = _fmt(_from);
    final to = _fmt(_to);
    final records = await ref.read(attendanceDaoProvider).getByStudentAndDateRange(widget.studentId, from, to);
    final payments = await ref.read(paymentDaoProvider).getByStudentAndDateRange(widget.studentId, from, to);
    return _ExportData(records: records, payments: payments);
  }

  Future<String> _buildPdf() async {
    final data = await _loadData();
    final student = _findStudent();
    if (student == null) {
      throw Exception('未找到当前学员，请返回详情页后重试');
    }
    final settings = ref.read(settingsProvider).valueOrNull ?? {};

    return PdfGenerator.generate(
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
    );
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
      final path = await _buildPdf();
      final student = _findStudent();
      if (student == null) throw Exception('未找到当前学员，请返回详情页后重试');

      if (mounted) {
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
                                  border: Border.all(color: kInkSecondary.withValues(alpha: 0.2)),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.of(previewCtx).pop(),
                                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
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
                                      '${student.name} 报告预览',
                                      style: Theme.of(previewCtx).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_fmt(_from)} - ${_fmt(_to)}',
                                      style: Theme.of(previewCtx).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              );

                              final shareButton = OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                onPressed: () async {
                                  await _shareFile(previewCtx, path);
                                },
                                icon: const Icon(Icons.share_outlined, size: 18),
                                label: const Text('分享'),
                              );

                              if (compact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
      final path = await _buildPdf();
      await _shareFile(context, path);
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
      final student = _findStudent();
      if (student == null) {
        throw Exception('未找到当前学员，请返回详情页后重试');
      }
      final path = await ExcelExporter.export(
        student: student,
        from: _fmt(_from),
        to: _fmt(_to),
        records: data.records,
        payments: data.payments,
      );
      final shared = await _shareFile(context, path);
      if (!shared) {
        return;
      }
      if (mounted) AppToast.showSuccess(context, 'Excel 已生成，请在系统分享面板中保存。');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleWatermark(bool value) async {
    if (!value) {
      final ok = await AppToast.showConfirm(context, '确认关闭水印吗？');
      if (!ok) return;
    }
    setState(() => _watermark = value);
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
    if (date != null) onPicked(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final student = _findStudent();
    final rangeLabel = '${_fmt(_from)} - ${_fmt(_to)}';
    final rangeDays = _to.difference(_from).inDays + 1;
    final message = _msgCtrl.text.trim();
    final hasMessage = message.isNotEmpty;
    final messageLength = message.length;

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
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: kInkSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '导出学习报告',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '可预览 PDF、直接分享或导出 Excel 记录。',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
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
                              child: const Icon(Icons.description_outlined, color: kPrimaryBlue),
                            ),
                            SizedBox(
                              width: compact ? constraints.maxWidth : constraints.maxWidth - 60,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '导出摘要',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '先确认报告对象、统计区间与寄语状态，再决定预览或直接分享。',
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
                                icon: Icons.person_outline,
                                label: '报告对象',
                                value: student?.name ?? '当前学员',
                                color: kPrimaryBlue,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _ExportSummaryMetric(
                                icon: Icons.date_range_outlined,
                                label: '统计区间',
                                value: '$rangeDays 天',
                                color: kSealRed,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _ExportSummaryMetric(
                                icon: Icons.chat_bubble_outline,
                                label: '寄语状态',
                                value: hasMessage ? '$messageLength 字' : '未填写',
                                color: hasMessage ? kGreen : kOrange,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _ExportSummaryMetric(
                                icon: Icons.water_drop_outlined,
                                label: 'PDF 水印',
                                value: _watermark ? '已启用' : '已关闭',
                                color: _watermark ? kPrimaryBlue : kInkSecondary,
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
                              icon: Icons.picture_as_pdf_outlined,
                              label: _watermark ? 'PDF 含水印' : 'PDF 纯净版',
                              color: _watermark ? kSealRed : kInkSecondary,
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
                title: '导出范围',
                subtitle: '开始和结束日期会同时影响 PDF 预览、分享和 Excel 记录。',
                trailing: '$rangeDays 天',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
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
                            label: '开始日期',
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
                            child: Icon(Icons.arrow_forward_outlined, size: 16, color: kInkSecondary),
                          ),
                        SizedBox(
                          width: fieldWidth,
                          child: _DateField(
                            label: '结束日期',
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
                title: '寄语内容',
                subtitle: '会展示在 PDF 报告末尾，可直接套用常用模板快速填写。',
                trailing: hasMessage ? '$messageLength / 200' : '未填写',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _msgCtrl,
                onChanged: (_) => setState(() {}),
                maxLength: 200,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '寄语',
                  counterText: '',
                  hintText: '例如：本月表现优秀，继续加油。',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        label: Text(message, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                        side: BorderSide(color: kInkSecondary.withValues(alpha: 0.2)),
                        onPressed: () {
                          _msgCtrl.text = message;
                          setState(() {});
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              _ExportSectionHeader(
                title: '导出选项',
                subtitle: '当前开关只影响 PDF 水印和印章效果，Excel 记录不会受影响。',
                trailing: _watermark ? '水印开启' : '水印关闭',
              ),
              const SizedBox(height: 12),
              _ExportSwitchTile(
                value: _watermark,
                icon: Icons.water_drop_outlined,
                title: '启用水印',
                subtitle: _watermark ? '导出 PDF 时附加印章和水印标识' : '当前将导出不带水印的纯净报告',
                onChanged: (value) {
                  _toggleWatermark(value);
                },
              ),
              const SizedBox(height: 24),
              _ExportSectionHeader(
                title: '导出动作',
                subtitle: '可先预览 PDF，再分享正式文件，或直接导出 Excel 记录。',
                trailing: _loading ? '处理中' : '可执行',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _ExportMetaBadge(
                    icon: Icons.preview_outlined,
                    label: '支持 PDF 预览',
                    color: kPrimaryBlue,
                  ),
                  _ExportMetaBadge(
                    icon: Icons.share_outlined,
                    label: '调用系统分享面板',
                    color: kSealRed,
                  ),
                  _ExportMetaBadge(
                    icon: Icons.table_view_outlined,
                    label: '可同时导出 Excel',
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _loading ? null : _previewPdf,
                          icon: const Icon(Icons.preview_outlined),
                          label: Text(_loading ? '处理中...' : '预览 PDF'),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _loading ? null : _sharePdf,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('分享 PDF'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: kGreen.withValues(alpha: 0.5)),
                            foregroundColor: kGreen,
                          ),
                          onPressed: _loading ? null : _exportExcel,
                          icon: const Icon(Icons.table_view_outlined),
                          label: const Text('导出 Excel'),
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
              width: trailing == null || compact ? constraints.maxWidth : constraints.maxWidth - 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
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
            const Icon(Icons.calendar_month_outlined, size: 18, color: kInkSecondary),
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
  final ValueChanged<bool> onChanged;

  const _ExportSwitchTile({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;

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
                            color: kPrimaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: kPrimaryBlue),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(subtitle, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Switch(value: value, onChanged: onChanged),
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
                        color: kPrimaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: kPrimaryBlue),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(subtitle, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(value: value, onChanged: onChanged),
                  ],
                );
        },
      ),
    );
  }
}
