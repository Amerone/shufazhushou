import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _fallbackAppName = '\u58a8\u97f5';
const _fallbackPackageName = String.fromEnvironment(
  'APP_PACKAGE_NAME',
  defaultValue: 'com.calligraphy.moyun',
);
const _fallbackVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.3',
);
const _fallbackBuildNumber = String.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: '4',
);

PackageInfo? _cachedPackageInfo;

PackageInfo _getFallbackPackageInfo() {
  return PackageInfo(
    appName: _fallbackAppName,
    packageName: _fallbackPackageName,
    version: _fallbackVersion,
    buildNumber: _fallbackBuildNumber,
  );
}

@visibleForTesting
void resetPackageInfoCache() {
  _cachedPackageInfo = null;
}

Future<PackageInfo> loadPackageInfo({
  Future<PackageInfo> Function()? reader,
}) async {
  final shouldUseCache = reader == null;
  if (shouldUseCache && _cachedPackageInfo != null) {
    return _cachedPackageInfo!;
  }

  final resolvedReader = reader ?? PackageInfo.fromPlatform;

  try {
    final info = await resolvedReader();
    if (info.appName.isEmpty && info.packageName.isEmpty) {
      throw Exception('PackageInfo returned empty values.');
    }
    if (shouldUseCache) {
      _cachedPackageInfo = info;
    }
    debugPrint('PackageInfo loaded: ${info.appName} v${info.version}');
    return info;
  } catch (error) {
    debugPrint('PackageInfo.fromPlatform failed: $error');
    return _getFallbackPackageInfo();
  }
}

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return loadPackageInfo();
});
