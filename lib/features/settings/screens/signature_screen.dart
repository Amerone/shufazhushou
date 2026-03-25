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
              onBack: () => context.pop(),
            ),
            Expanded(
              child: settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (settings) {
                  final path = settings['signature_path'];
                  final hasFile = path != null && path.isNotEmpty && File(path).existsSync();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '当前签名',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (hasFile)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
                                ),
                                child: Image.file(File(path), height: 160, fit: BoxFit.contain),
                              )
                            else
                              Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: kInkSecondary.withValues(alpha: 0.2),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.draw_outlined, size: 48, color: kInkSecondary),
                                      SizedBox(height: 12),
                                      Text('暂无签名，请上传用于 PDF 导出的签名', style: TextStyle(color: kInkSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('拍照上传'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _pick(context, ref, ImageSource.camera),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('相册选择'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _pick(context, ref, ImageSource.gallery),
                              ),
                            ),
                            if (hasFile) ...[
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final ok = await AppToast.showConfirm(context, '确认删除签名？');
                                  if (!ok) return;
                                  await ref.read(settingsProvider.notifier).set('signature_path', '');
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: kRed,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('删除签名'),
                              ),
                            ],
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
