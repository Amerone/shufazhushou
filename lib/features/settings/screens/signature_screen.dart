import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class SignatureScreen extends ConsumerWidget {
  const SignatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '签名管理',
              subtitle: '上传教师签名，用于 PDF 报告和导出资料的落款区域。',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (settings) {
                  final path = settings['signature_path'];
                  final hasFile = path != null && path.isNotEmpty && File(path).existsSync();
                  final statusColor = hasFile ? kGreen : kOrange;

                  return ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.draw_outlined, color: statusColor),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '签名状态',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        hasFile ? '当前签名会用于报告落款，重新上传后会立即替换。' : '上传后会自动用于 PDF 报告和导出资料的落款区域。',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    hasFile ? '已启用' : '未设置',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 720 ? 3 : 2;
                                final itemWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: itemWidth,
                                      child: _SignatureMetric(
                                        icon: Icons.verified_user_outlined,
                                        label: '当前状态',
                                        value: hasFile ? '已启用' : '待上传',
                                        color: statusColor,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: const _SignatureMetric(
                                        icon: Icons.picture_as_pdf_outlined,
                                        label: '导出用途',
                                        value: 'PDF 落款',
                                        color: kPrimaryBlue,
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: const _SignatureMetric(
                                        icon: Icons.aspect_ratio_outlined,
                                        label: '建议方向',
                                        value: '横向签名',
                                        color: kSealRed,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _SignatureSectionHeader(
                              title: '预览区域',
                              subtitle: hasFile ? '确认签名清晰度和横向比例，导出时会直接复用。' : '上传后会在这里展示当前签名效果。',
                              trailing: hasFile ? '本地文件' : '暂无文件',
                            ),
                            const SizedBox(height: 12),
                            if (hasFile)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.56),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: kPrimaryBlue.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.draw_outlined, size: 18, color: kPrimaryBlue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '签名预览',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: kPrimaryBlue,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            '建议横向',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Image.file(
                                      File(path),
                                      height: 160,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 160,
                                        alignment: Alignment.center,
                                        child: const Text(
                                          '签名文件无法读取，请重新上传',
                                          style: TextStyle(color: kInkSecondary),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.38),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: kInkSecondary.withValues(alpha: 0.2),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Icon(Icons.draw_outlined, size: 34, color: kInkSecondary),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '暂无签名，请上传用于 PDF 导出的签名',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kInkSecondary),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            const _SignatureSectionHeader(
                              title: '上传操作',
                              subtitle: '可直接拍照上传，或从相册选择现成的签名图片。',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                _SignatureTag(
                                  icon: Icons.camera_alt_outlined,
                                  label: '支持拍照上传',
                                  color: kPrimaryBlue,
                                ),
                                _SignatureTag(
                                  icon: Icons.photo_library_outlined,
                                  label: '支持相册替换',
                                  color: kSealRed,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 420;
                                final buttonWidth =
                                    compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: buttonWidth,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.camera_alt_outlined),
                                        label: const Text('拍照上传'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () => _pick(context, ref, ImageSource.camera),
                                      ),
                                    ),
                                    SizedBox(
                                      width: buttonWidth,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.photo_library_outlined),
                                        label: Text(hasFile ? '重新选择' : '相册选择'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () => _pick(context, ref, ImageSource.gallery),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (hasFile) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: kRed.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final compact = constraints.maxWidth < 420;
                                    final deleteButton = TextButton.icon(
                                      onPressed: () async {
                                        final ok = await AppToast.showConfirm(context, '确认删除签名？');
                                        if (!ok) return;
                                        await ref.read(settingsProvider.notifier).set('signature_path', '');
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: kRed,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('删除签名'),
                                    );

                                    if (compact) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '如果需要更换签名，可直接重新上传；删除后导出报告将不再显示签名。',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: deleteButton,
                                          ),
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '如果需要更换签名，可直接重新上传；删除后导出报告将不再显示签名。',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        deleteButton,
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _SignatureSectionHeader(
                              title: '上传建议',
                              subtitle: '提前处理背景和笔迹，可以明显提升 PDF 导出的签名质感。',
                            ),
                            SizedBox(height: 12),
                            _SignatureHintLine(
                              icon: Icons.info_outline,
                              text: '建议上传白底或透明底签名图，线条越清晰，导出效果越稳定。',
                            ),
                            SizedBox(height: 10),
                            _SignatureHintLine(
                              icon: Icons.brush_outlined,
                              text: '推荐使用深色笔迹，避免背景阴影和复杂纹理。',
                            ),
                            SizedBox(height: 10),
                            _SignatureHintLine(
                              icon: Icons.aspect_ratio_outlined,
                              text: '横向签名在报告页脚中的显示更自然，也更不容易被裁切。',
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

  Future<void> _pick(BuildContext context, WidgetRef ref, ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source);
    if (img == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, 'signature.jpg');
    await File(img.path).copy(dest);

    await ref.read(settingsProvider.notifier).set('signature_path', dest);
    if (context.mounted) AppToast.showSuccess(context, '签名已保存');
  }
}

class _SignatureSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;

  const _SignatureSectionHeader({
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

class _SignatureMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SignatureMetric({
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

class _SignatureTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SignatureTag({
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

class _SignatureHintLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SignatureHintLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: kInkSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
