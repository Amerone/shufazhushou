import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/seal_config.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/fee_summary_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/utils/excel_exporter.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';

class ExportConfigScreen extends ConsumerStatefulWidget {
  final String studentId;
  const ExportConfigScreen({super.key, required this.studentId});

  @override
  ConsumerState<ExportConfigScreen> createState() => _ExportConfigScreenState();
}

class _ExportConfigScreenState extends ConsumerState<ExportConfigScreen> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  final _msgCtrl = TextEditingController();
  bool _watermark = true;
  bool _loading = false;

  String _fmt(DateTime d) => formatDate(d);

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

  Future<_ExportData> _loadData() async {
    final from = _fmt(_from);
    final to = _fmt(_to);
    final records = await ref.read(attendanceDaoProvider).getByStudentAndDateRange(widget.studentId, from, to);
    final payments = await ref.read(paymentDaoProvider).getByStudent(widget.studentId);
    return _ExportData(records: records, payments: payments);
  }

  Future<void> _previewPdf() async {
    setState(() => _loading = true);
    try {
      final data = await _loadData();
      final students = ref.read(studentProvider).valueOrNull ?? [];
      final student = students.firstWhere((m) => m.student.id == widget.studentId).student;
      final settings = ref.read(settingsProvider).valueOrNull ?? {};
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
      );

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: kPaper,
              appBar: AppBar(title: Text('${student.name} 报告')),
              body: PdfPreview(build: (_) async => File(path).readAsBytes()),
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
    setState(() => _loading = true);
    try {
      final data = await _loadData();
      final students = ref.read(studentProvider).valueOrNull ?? [];
      final student = students.firstWhere((m) => m.student.id == widget.studentId).student;
      final settings = ref.read(settingsProvider).valueOrNull ?? {};
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
      );
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _loading = true);
    try {
      final data = await _loadData();
      final students = ref.read(studentProvider).valueOrNull ?? [];
      final student = students.firstWhere((m) => m.student.id == widget.studentId).student;
      final path = await ExcelExporter.export(
        student: student,
        from: _fmt(_from),
        to: _fmt(_to),
        records: data.records,
        payments: data.payments,
      );
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
      if (mounted) AppToast.showSuccess(context, '已保存至下载目录');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
      ),
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
          Text('生成报告', style: theme.textTheme.titleLarge?.copyWith(fontSize: 21)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('开始', style: theme.textTheme.bodySmall),
                  subtitle: Text(_fmt(_from)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _from,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _from = d);
                  },
                ),
              ),
              const Text(' - '),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('结束', style: theme.textTheme.bodySmall),
                  subtitle: Text(_fmt(_to)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _to,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _to = d);
                  },
                ),
              ),
            ],
          ),
          TextField(
            controller: _msgCtrl,
            decoration: const InputDecoration(
              labelText: '寄语',
              counterText: '',
              hintText: '如：本月表现优秀，继续加油！',
            ),
            maxLength: 200,
            maxLines: 3,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: const [
              _PresetChip('本月表现优秀，继续加油！'),
              _PresetChip('进步明显，期待更好的作品'),
              _PresetChip('基础扎实，注意保持练习'),
              _PresetChip('笔法渐入佳境，望持之以恒'),
            ].map((chip) => ActionChip(
              label: Text(chip.text, style: const TextStyle(fontSize: 12)),
              onPressed: () {
                _msgCtrl.text = chip.text;
                setState(() {});
              },
            )).toList(),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用水印'),
            value: _watermark,
            onChanged: (v) async {
              if (!v) {
                final ok = await AppToast.showConfirm(context, '确认关闭水印？');
                if (!ok) return;
              }
              setState(() => _watermark = v);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _previewPdf,
                  child: const Text('预览 PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _sharePdf,
                  child: const Text('分享 PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _exportExcel,
                  child: const Text('导出 Excel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportData {
  final List<Attendance> records;
  final List<Payment> payments;
  const _ExportData({required this.records, required this.payments});
}

class _PresetChip {
  final String text;
  const _PresetChip(this.text);
}
