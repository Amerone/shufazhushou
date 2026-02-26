import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/toast.dart';

class SignatureScreen extends ConsumerWidget {
  const SignatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('签名管理')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (settings) {
          final path = settings['signature_path'];
          final hasFile = path != null && path.isNotEmpty && File(path).existsSync();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasFile)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.file(File(path), height: 150, fit: BoxFit.contain),
                    ),
                  )
                else
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: kInkSecondary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('暂无签名')),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('拍照上传'),
                  onPressed: () => _pick(context, ref, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('相册选择'),
                  onPressed: () => _pick(context, ref, ImageSource.gallery),
                ),
                if (hasFile) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final ok = await AppToast.showConfirm(context, '确认删除签名？');
                      if (!ok) return;
                      await ref.read(settingsProvider.notifier).set('signature_path', '');
                    },
                    style: TextButton.styleFrom(foregroundColor: kRed),
                    child: const Text('删除签名'),
                  ),
                ],
              ],
            ),
          );
        },
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
