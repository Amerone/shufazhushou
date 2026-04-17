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
    FocusScope.of(context).unfocus();
    try {
      await ref.read(settingsProvider.notifier).setAll({
        'seal_text': _config.text,
        'seal_font': _config.fontStyle,
        'seal_layout': _config.layout,
        'seal_border': _config.border,
      });
      if (mounted) AppToast.showSuccess(context, '印章设置已保存');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    }
  }

  String _optionLabel(Map<String, String> options, String value) {
    return options[value] ?? value;
  }

  Widget _buildOptionSection(
    String title,
    Map<String, String> options,
    String currentValue,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kInkSecondary.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SealSectionHeader(title: title),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: options.entries.map((entry) {
                  final selected = currentValue == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.5),
                    selectedColor: kPrimaryBlue.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: selected
                          ? kPrimaryBlue
                          : kInkSecondary.withValues(alpha: 0.2),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? kPrimaryBlue : kInkSecondary,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                    onSelected: (_) => onChanged(entry.key),
                  );
                }).toList(),
              ),
            ],
          ),
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
              title: '印章样式',
              subtitle: '用于启动页和报告封面。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (settings) {
                  _initFromSettings(settings);
                  return ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 560;
                            final preview = Container(
                              width: compact ? double.infinity : 220,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: kInkSecondary.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Center(
                                child: SealStampWidget(
                                  config: _config,
                                  size: compact ? 132 : 148,
                                ),
                              ),
                            );
                            final summary = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SealSectionHeader(title: '实时预览'),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _SealInfoBadge(
                                      icon: Icons.font_download_outlined,
                                      label: _optionLabel(
                                        _fontOptions,
                                        _config.fontStyle,
                                      ),
                                      color: kSealRed,
                                    ),
                                    _SealInfoBadge(
                                      icon: Icons.grid_view_rounded,
                                      label: _optionLabel(
                                        _layoutOptions,
                                        _config.layout,
                                      ),
                                      color: kPrimaryBlue,
                                    ),
                                    _SealInfoBadge(
                                      icon: Icons.crop_square_outlined,
                                      label: _optionLabel(
                                        _borderOptions,
                                        _config.border,
                                      ),
                                      color: kGreen,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '当前文字',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _config.text,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: kSealRed,
                                      ),
                                ),
                              ],
                            );

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  preview,
                                  const SizedBox(height: 18),
                                  summary,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                preview,
                                const SizedBox(width: 18),
                                Expanded(child: summary),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SealSectionHeader(title: '文字与样式'),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SealInfoBadge(
                                  icon: Icons.spellcheck_outlined,
                                  label: '${_config.text.length}/4 字',
                                  color: kPrimaryBlue,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _textCtrl,
                              maxLength: 4,
                              decoration: const InputDecoration(
                                labelText: '印章文字',
                                hintText: '请输入 1-4 个字',
                                counterText: '',
                                prefixIcon: Icon(Icons.edit_note_outlined),
                              ),
                              onChanged: (value) {
                                setState(
                                  () => _config = _config.copyWith(
                                    text: value.isNotEmpty
                                        ? value
                                        : kDefaultSealText,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            _buildOptionSection(
                              '字体',
                              _fontOptions,
                              _config.fontStyle,
                              (v) => setState(
                                () => _config = _config.copyWith(fontStyle: v),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildOptionSection(
                              '布局',
                              _layoutOptions,
                              _config.layout,
                              (v) => setState(
                                () => _config = _config.copyWith(layout: v),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildOptionSection(
                              '边框',
                              _borderOptions,
                              _config.border,
                              (v) => setState(
                                () => _config = _config.copyWith(border: v),
                              ),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              onPressed: _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('保存设置'),
                            ),
                          ],
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

class _SealSectionHeader extends StatelessWidget {
  final String title;

  const _SealSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SealInfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SealInfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color == kInkSecondary ? kInkSecondary : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: color == kInkSecondary ? 0.06 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
