import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/providers/package_info_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  // 预加载 PackageInfo，确保原生通道在应用启动时就完成初始化
  await loadPackageInfo();
  runApp(const ProviderScope(child: App()));
}
