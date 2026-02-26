import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/seal_config.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/seal_stamp_widget.dart';

class SealStampScreen extends ConsumerStatefulWidget {
  const SealStampScreen({super.key});

  @override
  ConsumerState<SealStampScreen> createState() => _SealStampScreenState();
}

class _SealStampScreenState extends ConsumerState<SealStampScreen> {
  TextEditingController? _textCtrl;
  SealConfig _config = const SealConfig();
  bool _initialized = false;

  static const _fontOptions = {
    'xiaozhuan': '小篆',
    'miuzhuan': '缪篆',
    'dazhuan': '大篆',
  };

  static const _layoutOptions = {
    'grid': '均分',
    'diagonal': '对角',
    'full_white': '满白',
    'fine_red': '细朱',
  };

  static const _borderOptions = {
    'full': '完整',
    'broken': '残破',
    'borrowed': '借边',
    'none': '无边',
  };

  @override
  void dispose() {
    _textCtrl?.dispose();
    super.dispose();
  }

  void _initFromSettings(Map<String, String> settings) {
    if (_initialized) return;
    _config = SealConfig.fromSettings(settings);
    _textCtrl = TextEditingController(text: _config.text);
    _initialized = true;
  }

  Future<void> _save() async {
    try {
      await ref.read(settingsProvider.notifier).setAll({
        'seal_text': _config.text,
        'seal_font': _config.fontStyle,
        'seal_layout': _config.layout,
        'seal_border': _config.border,
      });
      if (mounted) AppToast.showSuccess(context, '压角章设置已保存');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('压角章设置')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (settings) {
          _initFromSettings(settings);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 实时预览
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: kPaper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kInkSecondary.withValues(alpha: 0.2)),
                  ),
                  child: SealStampWidget(config: _config, size: 120),
                ),
              ),
              const SizedBox(height: 24),
              // 说明文字
              const Text(
                '压角章将显示在启动页和 PDF 报告封面，与签名各司其职',
                style: TextStyle(fontSize: 12, color: kInkSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // 印章文字
              TextField(
                controller: _textCtrl,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: '印章文字',
                  counterText: '',
                  hintText: '1-4个字',
                ),
                onChanged: (v) {
                  setState(() => _config = _config.copyWith(text: v.isNotEmpty ? v : kDefaultSealText));
                },
              ),
              const SizedBox(height: 16),
              // 字体选择
              Text('字体', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _fontOptions.entries.map((e) {
                  final selected = _config.fontStyle == e.key;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _config = _config.copyWith(fontStyle: e.key));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 布局选择
              Text('布局', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _layoutOptions.entries.map((e) {
                  final selected = _config.layout == e.key;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _config = _config.copyWith(layout: e.key));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 边框选择
              Text('边框', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _borderOptions.entries.map((e) {
                  final selected = _config.border == e.key;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _config = _config.copyWith(border: e.key));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }
}
