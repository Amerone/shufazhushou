import 'dart:async';
import 'dart:io';

import 'package:share_plus/share_plus.dart';

bool shouldTreatShareAsCompleted(ShareResultStatus status) {
  return status != ShareResultStatus.dismissed;
}

Future<void> deleteExportTempFile(String? path) async {
  final trimmedPath = path?.trim();
  if (trimmedPath == null || trimmedPath.isEmpty) {
    return;
  }

  try {
    final file = File(trimmedPath);
    if (await file.exists()) {
      await file.delete();
    }
  } on FileSystemException {
    // Ignore cleanup failures for temporary export artifacts.
  }
}

Future<void> cleanupExportTempFileForShare(
  String? path,
  ShareResultStatus status, {
  required Duration deferredDelay,
}) async {
  if (!shouldTreatShareAsCompleted(status) || deferredDelay <= Duration.zero) {
    await deleteExportTempFile(path);
    return;
  }

  unawaited(
    Future<void>.delayed(deferredDelay, () => deleteExportTempFile(path)),
  );
}
