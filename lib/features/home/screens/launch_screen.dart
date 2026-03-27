import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/seal_config.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/seal_stamp_widget.dart';

class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/');
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull ?? {};
    final sealConfig = SealConfig.fromSettings(settings);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720 || constraints.maxWidth < 380;
            final emblemSize = compact ? 74.0 : 88.0;
            final titleSize = compact ? 36.0 : 44.0;
            final mottoSize = compact ? 16.0 : 18.0;
            final sealSize = compact ? 58.0 : 68.0;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, compact ? 20 : 28, 24, compact ? 24 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeTransition(
                      opacity: _fade,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: kInkSecondary.withValues(alpha: 0.14)),
                          ),
                          child: Text(
                            '离线优先 · 本地保存',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kPrimaryBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale: _scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: emblemSize,
                              height: emblemSize,
                              decoration: BoxDecoration(
                                color: kSealRed.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: kSealRed.withValues(alpha: 0.55),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.brush_outlined,
                                size: compact ? 34 : 40,
                                color: kSealRed,
                              ),
                            ),
                            SizedBox(height: compact ? 22 : 26),
                            Text(
                              kDefaultInstitutionName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'MaShanZheng',
                                fontSize: titleSize,
                                letterSpacing: compact ? 4 : 6,
                                height: 1.2,
                                color: const Color(0xFF26221D),
                                shadows: [
                                  Shadow(
                                    blurRadius: 18,
                                    color: kPrimaryBlue.withValues(alpha: 0.12),
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 14),
                            Text(
                              kDefaultInstitutionMotto,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'MaShanZheng',
                                fontSize: mottoSize,
                                letterSpacing: 1.6,
                                color: kInkSecondary,
                              ),
                            ),
                            SizedBox(height: compact ? 20 : 28),
                            SizedBox(
                              width: compact ? 144 : 160,
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                valueColor: const AlwaysStoppedAnimation<Color>(kSealRed),
                                backgroundColor: kPrimaryBlue.withValues(alpha: 0.08),
                              ),
                            ),
                            SizedBox(height: compact ? 16 : 18),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.56),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '正在整理课堂记录',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: kInkSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    FadeTransition(
                      opacity: _fade,
                      child: LayoutBuilder(
                        builder: (context, footerConstraints) {
                          final stacked = footerConstraints.maxWidth < 380;
                          final infoCard = GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '欢迎回来',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '学生档案、课时记录与缴费数据均保存在本机，打开即可继续使用。',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );

                          final seal = Opacity(
                            opacity: 0.88,
                            child: SealStampWidget(config: sealConfig, size: sealSize),
                          );

                          if (stacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                infoCard,
                                const SizedBox(height: 12),
                                seal,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: infoCard),
                              const SizedBox(width: 16),
                              seal,
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

