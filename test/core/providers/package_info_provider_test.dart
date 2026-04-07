import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/providers/package_info_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(resetPackageInfoCache);
  tearDown(resetPackageInfoCache);

  test('loadPackageInfo returns platform data when available', () async {
    final result = await loadPackageInfo(
      reader: () async => PackageInfo(
        appName: 'Test App',
        packageName: 'com.example.test',
        version: '9.9.9',
        buildNumber: '99',
      ),
    );

    expect(result.appName, 'Test App');
    expect(result.packageName, 'com.example.test');
    expect(result.version, '9.9.9');
    expect(result.buildNumber, '99');
  });

  test('loadPackageInfo falls back when platform lookup fails', () async {
    final result = await loadPackageInfo(
      reader: () async => throw Exception('packageInfo is null'),
    );

    expect(result.appName, '\u58a8\u97f5');
    expect(result.packageName, 'com.calligraphy.moyun');
    expect(result.version, '1.0.3');
    expect(result.buildNumber, '4');
  });
}
