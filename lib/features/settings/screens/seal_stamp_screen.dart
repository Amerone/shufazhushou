import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/seal_config.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
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

  Widget _buildOptionSection(
    BuildContext context,
    String title,
    Map<String, String> options,
    String currentValue,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: kInkSecondary,
                ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.entries.map((e) {
            final selected = currentValue == e.key;
            return ChoiceChip(
              label: Text(e.value),
              selected: selected,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              selectedColor: kPrimaryBlue.withValues(alpha: 0.1),
              side: BorderSide(
                color: selected ? kPrimaryBlue : kInkSecondary.withValues(alpha: 0.2),
              ),
              labelStyle: TextStyle(
                color: selected ? kPrimaryBlue : kInkSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => onChanged(e.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '压角章设置',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (settings) {
                  _initFromSettings(settings);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: kInkSecondary.withValues(alpha: 0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: SealStampWidget(config: _config, size: 140),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '压角章将显示在启动页和 PDF 报告封面，与签名各司其职',
                              style: TextStyle(fontSize: 13, color: kInkSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _textCtrl,
                              maxLength: 4,
                              decoration: InputDecoration(
                                labelText: '印章文字',
                                counterText: '',
                                hintText: '1-4个字',
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: kInkSecondary.withValues(alpha: 0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: kInkSecondary.withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                              onChanged: (v) {
                                setState(() => _config = _config.copyWith(
                                    text: v.isNotEmpty ? v : kDefaultSealText));
                              },
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 24),
                            _buildOptionSection(
                              context,
                              '字体',
                              _fontOptions,
                              _config.fontStyle,
                              (v) => setState(() => _config = _config.copyWith(fontStyle: v)),
                            ),
                            const SizedBox(height: 24),
                            _buildOptionSection(
                              context,
                              '布局',
                              _layoutOptions,
                              _config.layout,
                              (v) => setState(() => _config = _config.copyWith(layout: v)),
                            ),
                            const SizedBox(height: 24),
                            _buildOptionSection(
                              context,
                              '边框',
                              _borderOptions,
                              _config.border,
                              (v) => setState(() => _config = _config.copyWith(border: v)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _save,
                        child: const Text(
                          '保存设置',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}