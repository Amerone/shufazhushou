import 'package:flutter/material.dart';

import '../theme.dart';
import 'interaction_feedback.dart';

class AppToast {
  static void showSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: kGreen,
      ),
    );
  }

  static void showError(BuildContext context, String msg) {
    _showDialog<void>(
      context: context,
      icon: Icons.error_outline,
      accentColor: kRed,
      title: '操作失败',
      message: msg,
      actions: (dialogCtx) => [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('知道了'),
          ),
        ),
      ],
    );
  }

  static Future<bool> showConfirm(BuildContext context, String msg) async {
    final result = await _showDialog<bool>(
      context: context,
      icon: Icons.help_outline,
      accentColor: kOrange,
      title: '请确认',
      message: msg,
      actions: (dialogCtx) => [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: kRed,
              backgroundColor: kRed.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              await InteractionFeedback.selection(dialogCtx);
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop(true);
              }
            },
            child: const Text('确认'),
          ),
        ),
      ],
    );
    return result ?? false;
  }

  static Future<T?> _showDialog<T>({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String message,
    required List<Widget> Function(BuildContext dialogCtx) actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kPaperCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(dialogCtx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: Theme.of(dialogCtx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                children: actions(dialogCtx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
