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
import '../../../shared/widgets/glass_card.dart';

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
    return GlassCard(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
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
            '生成报告',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _from,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _from = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '开始时间',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.5),
                    ),
                    child: Text(_fmt(_from), style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_outlined, size: 16, color: kInkSecondary),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _to,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _to = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '结束时间',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.5),
                    ),
                    child: Text(_fmt(_to), style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _msgCtrl,
            decoration: InputDecoration(
              labelText: '寄语',
              counterText: '',
              hintText: '如：本月表现优秀，继续加油！',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
            ),
            maxLength: 200,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _PresetChip('本月表现优秀，继续加油！'),
              _PresetChip('进步明显，期待更好的作品'),
              _PresetChip('基础扎实，注意保持练习'),
              _PresetChip('笔法渐入佳境，望持之以恒'),
            ].map((chip) => ActionChip(
              label: Text(chip.text, style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              side: BorderSide(color: kInkSecondary.withValues(alpha: 0.2)),
              onPressed: () {
                _msgCtrl.text = chip.text;
                setState(() {});
              },
            )).toList(),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用水印', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('导出PDF时包含水印', style: TextStyle(fontSize: 12, color: kInkSecondary)),
            value: _watermark,
            activeThumbColor: kPrimaryBlue,
            onChanged: (v) async {
              if (!v) {
                final ok = await AppToast.showConfirm(context, '确认关闭水印？');
                if (!ok) return;
              }
              setState(() => _watermark = v);
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _previewPdf,
                  icon: const Icon(Icons.preview_outlined),
                  label: const Text('预览 PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
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
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
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
