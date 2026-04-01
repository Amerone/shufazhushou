import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/screens/initial_setup_screen.dart';
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
import 'shared/utils/interaction_feedback.dart';

final _router = GoRouter(
  initialLocation: '/launch',
  routes: [
    GoRoute(path: '/launch', builder: (ctx, s) => const LaunchScreen()),
    GoRoute(path: '/setup', builder: (ctx, s) => const InitialSetupScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (ctx, s) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/students',
              builder: (ctx, s) => const StudentListScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (ctx, s) => const StudentFormScreen(),
                ),
                GoRoute(
                  path: 'import',
                  builder: (ctx, s) => const StudentImportScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (ctx, s) =>
                      StudentDetailScreen(studentId: s.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (ctx, s) =>
                          StudentFormScreen(studentId: s.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/statistics',
              builder: (ctx, s) => const StatisticsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (ctx, s) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'templates',
                  builder: (ctx, s) => const TemplateScreen(),
                ),
                GoRoute(
                  path: 'signature',
                  builder: (ctx, s) => const SignatureScreen(),
                ),
                GoRoute(
                  path: 'backup',
                  builder: (ctx, s) => const BackupScreen(),
                ),
                GoRoute(
                  path: 'ai',
                  builder: (ctx, s) => const AiSettingsScreen(),
                ),
                GoRoute(
                  path: 'seal',
                  builder: (ctx, s) => const SealStampScreen(),
                ),
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
      body: _ShellBodyMotion(index: shell.currentIndex, child: shell),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: _BrushNavigationBar(
          currentIndex: shell.currentIndex,
          onSelect: shell.goBranch,
          shadowColor: theme.colorScheme.shadow,
        ),
      ),
    );
  }
}

class _ShellBodyMotion extends StatefulWidget {
  final int index;
  final Widget child;

  const _ShellBodyMotion({required this.index, required this.child});

  @override
  State<_ShellBodyMotion> createState() => _ShellBodyMotionState();
}

class _ShellBodyMotionState extends State<_ShellBodyMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.988,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant _ShellBodyMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    unawaited(_controller.forward(from: 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class _BrushNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Color shadowColor;

  const _BrushNavigationBar({
    required this.currentIndex,
    required this.onSelect,
    required this.shadowColor,
  });

  static const _items = [
    _NavItemData(
      label: '首页',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavItemData(
      label: '学生',
      icon: Icons.people_outline,
      selectedIcon: Icons.people_alt_rounded,
    ),
    _NavItemData(
      label: '统计',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
    ),
    _NavItemData(
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.86),
        border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            return Expanded(
              child: _BrushNavItem(
                data: item,
                selected: currentIndex == index,
                onTap: () => onSelect(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BrushNavItem extends StatelessWidget {
  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _BrushNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? kPrimaryBlue : kInkSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return kPrimaryBlue.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.hovered)) {
            return kPrimaryBlue.withValues(alpha: 0.03);
          }
          return null;
        }),
        onTap: () {
          if (!selected) {
            unawaited(InteractionFeedback.pageTurn(context));
          }
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? kPrimaryBlue.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? data.selectedIcon : data.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: selected ? 26 : 8,
                height: 4,
                decoration: BoxDecoration(
                  color: selected
                      ? kSealRed.withValues(alpha: 0.9)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '墨韵',
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
