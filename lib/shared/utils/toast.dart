import 'package:flutter/material.dart';
import '../theme.dart';

class AppToast {
  static void showSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kGreen,
      ),
    );
  }

  static void showError(BuildContext context, String msg) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('错误'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  static Future<bool> showConfirm(BuildContext context, String msg) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
