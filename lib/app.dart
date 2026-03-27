import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/screens/launch_screen.dart';
import 'features/settings/screens/backup_screen.dart';
import 'features/settings/screens/ai_settings_screen.dart';
import 'features/settings/screens/seal_stamp_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/settings/screens/signature_screen.dart';
import 'features/settings/screens/template_screen.dart';
import 'features/statistics/screens/statistics_screen.dart';
import 'features/students/screens/student_detail_screen.dart';
import 'features/students/screens/student_form_screen.dart';
import 'features/students/screens/student_import_screen.dart';
import 'features/students/screens/student_list_screen.dart';
import 'shared/theme.dart';

final _router = GoRouter(
  initialLocation: '/launch',
  routes: [
    GoRoute(path: '/launch', builder: (ctx, s) => const LaunchScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (ctx, s) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/students',
              builder: (ctx, s) => const StudentListScreen(),
              routes: [
                GoRoute(path: 'create', builder: (ctx, s) => const StudentFormScreen()),
                GoRoute(path: 'import', builder: (ctx, s) => const StudentImportScreen()),
                GoRoute(
                  path: ':id',
                  builder: (ctx, s) => StudentDetailScreen(studentId: s.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (ctx, s) => StudentFormScreen(studentId: s.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/statistics', builder: (ctx, s) => const StatisticsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (ctx, s) => const SettingsScreen(),
              routes: [
                GoRoute(path: 'templates', builder: (ctx, s) => const TemplateScreen()),
                GoRoute(path: 'signature', builder: (ctx, s) => const SignatureScreen()),
                GoRoute(path: 'backup', builder: (ctx, s) => const BackupScreen()),
                GoRoute(path: 'ai', builder: (ctx, s) => const AiSettingsScreen()),
                GoRoute(path: 'seal', builder: (ctx, s) => const SealStampScreen()),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldWithNav({required this.shell});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: NavigationBar(
              height: 72,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: shell.goBranch,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
                NavigationDestination(icon: Icon(Icons.people_outline), label: '学生'),
                NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: '统计'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '书法助手',
      theme: buildAppTheme(),
      routerConfig: _router,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
