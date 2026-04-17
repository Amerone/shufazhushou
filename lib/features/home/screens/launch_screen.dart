import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/seal_config.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/seal_stamp_widget.dart';

class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen>
    with SingleTickerProviderStateMixin {
  bool _navigating = false;
  late final AnimationController _controller;
  late final Animation<double> _badgeOpacity;
  late final Animation<double> _titleReveal;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleDrift;
  late final Animation<double> _mottoOpacity;
  late final Animation<double> _mottoDrift;
  late final Animation<double> _sealOpacity;
  late final Animation<double> _sealScale;
  late final Animation<double> _sealTilt;
  late final Animation<Offset> _sealOffset;
  late final Animation<double> _footerOpacity;
  late final Animation<double> _sceneOpacity;
  late final Animation<double> _sceneScale;
  late final Animation<double> _inkBloom;

  @override
  void initState() {
    super.initState();
    ref.read(settingsProvider);
    ref.read(studentProvider);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );

    _badgeOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.02, 0.16, curve: Curves.easeOutCubic),
    );
    _titleReveal = Tween<double>(begin: -0.16, end: 1.18).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.48, curve: Curves.easeInOutCubic),
      ),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.22, curve: Curves.easeOutCubic),
    );
    _titleDrift = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.44, curve: Curves.easeOutCubic),
      ),
    );
    _mottoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.36, 0.58, curve: Curves.easeOutCubic),
    );
    _mottoDrift = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.34, 0.58, curve: Curves.easeOutCubic),
      ),
    );
    _sealOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.54, 0.62, curve: Curves.easeOutCubic),
    );
    _sealScale = Tween<double>(begin: 0.16, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.56, 0.82, curve: Curves.elasticOut),
      ),
    );
    _sealTilt = Tween<double>(begin: -0.22, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.56, 0.76, curve: Curves.easeOutCubic),
      ),
    );
    _sealOffset = Tween<Offset>(begin: const Offset(26, -28), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.54, 0.78, curve: Curves.easeOutCubic),
          ),
        );
    _footerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.46, 0.72, curve: Curves.easeOutCubic),
    );
    _sceneOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.84, 1.0, curve: Curves.easeInCubic),
      ),
    );
    _sceneScale = Tween<double>(begin: 1, end: 1.035).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.76, 1.0, curve: Curves.easeInOutCubic),
      ),
    );
    _inkBloom = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1.0, curve: Curves.easeOutCubic),
    );

    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _navigateNext();
      });
    });

    unawaited(_controller.forward());
  }

  Future<void> _navigateNext() async {
    if (_navigating || !mounted) return;
    _navigating = true;

    try {
      final cachedStudents = ref.read(studentProvider).valueOrNull;
      final hasStudents =
          cachedStudents?.isNotEmpty ??
          (await ref.read(studentProvider.future)).isNotEmpty;
      if (!mounted) return;
      context.go(hasStudents ? '/' : '/setup');
    } catch (_) {
      if (!mounted) return;
      context.go('/');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull ?? {};
    final sealConfig = SealConfig.fromSettings(settings);
    final theme = Theme.of(context);
    final institutionName = settings['institution_name']?.trim();
    final institutionMotto = settings['institution_motto']?.trim();
    final titleText = institutionName?.isNotEmpty == true
        ? institutionName!
        : kDefaultInstitutionName;
    final mottoText = institutionMotto?.isNotEmpty == true
        ? institutionMotto!
        : kDefaultInstitutionMotto;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Semantics(
        button: true,
        label: '跳过开屏动画',
        hint: '进入应用',
        onTap: _navigateNext,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _navigateNext,
          child: InkWashBackground(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxHeight < 720 ||
                        constraints.maxWidth < 380;
                    final titleSize = compact ? 42.0 : 54.0;
                    final mottoSize = compact ? 16.0 : 18.0;
                    final sealSize = compact ? 62.0 : 76.0;
                    final contentWidth = constraints.maxWidth > 460
                        ? 420.0
                        : constraints.maxWidth;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: _InkBloomOverlay(progress: _inkBloom.value),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              compact ? 20 : 28,
                              24,
                              compact ? 24 : 32,
                            ),
                            child: Opacity(
                              opacity: _sceneOpacity.value,
                              child: Transform.scale(
                                scale: _sceneScale.value,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Opacity(
                                      opacity: _badgeOpacity.value,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.56,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: kInkSecondary.withValues(
                                                alpha: 0.14,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            '离线优先 · 本地保存',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: kPrimaryBlue,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Center(
                                      child: SizedBox(
                                        width: contentWidth,
                                        height: compact ? 212 : 240,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Align(
                                              alignment: const Alignment(
                                                0,
                                                -0.08,
                                              ),
                                              child: Opacity(
                                                opacity:
                                                    0.22 +
                                                    (_mottoOpacity.value * 0.2),
                                                child: Transform.scale(
                                                  scale:
                                                      0.96 +
                                                      (_inkBloom.value * 0.08),
                                                  child: Container(
                                                    width: compact ? 230 : 280,
                                                    height: compact ? 180 : 210,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            220,
                                                          ),
                                                      gradient: RadialGradient(
                                                        colors: [
                                                          kPrimaryBlue
                                                              .withValues(
                                                                alpha: 0.08,
                                                              ),
                                                          kInkSecondary
                                                              .withValues(
                                                                alpha: 0.05,
                                                              ),
                                                          Colors.transparent,
                                                        ],
                                                        stops: const [
                                                          0.0,
                                                          0.48,
                                                          1.0,
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Align(
                                              alignment: Alignment.center,
                                              child: Padding(
                                                padding: EdgeInsets.only(
                                                  left: compact ? 8 : 12,
                                                  right: compact ? 32 : 44,
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Transform.translate(
                                                      offset: Offset(
                                                        0,
                                                        _titleDrift.value,
                                                      ),
                                                      child: Opacity(
                                                        opacity:
                                                            _titleOpacity.value,
                                                        child: _BrushRevealText(
                                                          text: titleText,
                                                          progress: _titleReveal
                                                              .value,
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'MaShanZheng',
                                                            fontSize: titleSize,
                                                            letterSpacing:
                                                                compact
                                                                ? 4.5
                                                                : 6.5,
                                                            height: 1.15,
                                                            color: const Color(
                                                              0xFF26221D,
                                                            ),
                                                            shadows: [
                                                              Shadow(
                                                                blurRadius: 20,
                                                                color: kPrimaryBlue
                                                                    .withValues(
                                                                      alpha:
                                                                          0.12,
                                                                    ),
                                                                offset:
                                                                    const Offset(
                                                                      0,
                                                                      8,
                                                                    ),
                                                              ),
                                                              Shadow(
                                                                blurRadius: 8,
                                                                color: kInkSecondary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.08,
                                                                    ),
                                                                offset:
                                                                    const Offset(
                                                                      0,
                                                                      2,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: compact ? 16 : 18,
                                                    ),
                                                    Transform.translate(
                                                      offset: Offset(
                                                        0,
                                                        _mottoDrift.value,
                                                      ),
                                                      child: Opacity(
                                                        opacity:
                                                            _mottoOpacity.value,
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              width: compact
                                                                  ? 128
                                                                  : 150,
                                                              height: 1.4,
                                                              decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                  colors: [
                                                                    Colors
                                                                        .transparent,
                                                                    kInkSecondary
                                                                        .withValues(
                                                                          alpha:
                                                                              0.32,
                                                                        ),
                                                                    kInkSecondary
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              height: compact
                                                                  ? 10
                                                                  : 12,
                                                            ),
                                                            Text(
                                                              mottoText,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    'MaShanZheng',
                                                                fontSize:
                                                                    mottoSize,
                                                                letterSpacing:
                                                                    1.8,
                                                                color:
                                                                    kInkSecondary,
                                                                height: 1.35,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Align(
                                              alignment: compact
                                                  ? const Alignment(0.95, 0.04)
                                                  : const Alignment(
                                                      0.98,
                                                      -0.02,
                                                    ),
                                              child: Transform.translate(
                                                offset: _sealOffset.value,
                                                child: Transform.rotate(
                                                  angle: _sealTilt.value,
                                                  child: Transform.scale(
                                                    scale: _sealScale.value,
                                                    child: Opacity(
                                                      opacity: _sealOpacity
                                                          .value
                                                          .clamp(0.0, 1.0)
                                                          .toDouble(),
                                                      child: SealStampWidget(
                                                        config: sealConfig,
                                                        size: sealSize,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Opacity(
                                      opacity: _footerOpacity.value,
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              constraints: const BoxConstraints(
                                                maxWidth: 420,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.42,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: kInkSecondary
                                                      .withValues(alpha: 0.12),
                                                ),
                                              ),
                                              child: Text(
                                                '学生档案、课时记录与缴费数据均保存在本机，开卷即可续写。',
                                                textAlign: TextAlign.center,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: kInkSecondary,
                                                      height: 1.4,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              '点击任意位置可跳过动画',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: kInkSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BrushRevealText extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle style;

  const _BrushRevealText({
    required this.text,
    required this.progress,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final lead = progress.clamp(0.0, 1.0).toDouble();
    final tail = (lead - 0.18).clamp(0.0, 1.0).toDouble();
    final feather = (lead + 0.1).clamp(0.0, 1.0).toDouble();
    final mid = lead < tail ? tail : lead;
    final end = feather < mid ? mid : feather;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black,
            Colors.black,
            Colors.black.withValues(alpha: 0.34),
            Colors.transparent,
          ],
          stops: [0.0, tail, mid, end],
        ).createShader(bounds);
      },
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}

class _InkBloomOverlay extends StatelessWidget {
  final double progress;

  const _InkBloomOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    final mainScale = lerpDouble(0.82, 1.55, progress)!;
    final sealScale = lerpDouble(0.7, 1.35, progress)!;
    final mainRadius = lerpDouble(0.48, 1.12, progress)!;
    final sealRadius = lerpDouble(0.36, 1.0, progress)!;

    return IgnorePointer(
      child: Opacity(
        opacity: 0.42 * progress,
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(0, -0.04),
              child: Transform.scale(
                scale: mainScale,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      radius: mainRadius,
                      colors: [
                        kPrimaryBlue.withValues(alpha: 0.14),
                        kInkSecondary.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.46, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.22, 0.1),
              child: Transform.scale(
                scale: sealScale,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(240),
                    gradient: RadialGradient(
                      radius: sealRadius,
                      colors: [
                        kSealRed.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
