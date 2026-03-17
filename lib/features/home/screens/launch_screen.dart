import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/seal_config.dart';
import '../../../core/providers/settings_provider.dart';
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

    return Scaffold(
      body: InkWashBackground(
        child: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: kSealRed.withValues(alpha: 0.15),
                          border: Border.all(
                            color: kSealRed.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.brush_outlined,
                          size: 36,
                          color: kSealRed,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        kDefaultInstitutionName,
                        style: TextStyle(
                          fontFamily: 'MaShanZheng',
                          fontSize: 44,
                          letterSpacing: 6,
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
                      const SizedBox(height: 14),
                      const Text(
                        kDefaultInstitutionMotto,
                        style: TextStyle(
                          fontFamily: 'MaShanZheng',
                          fontSize: 18,
                          letterSpacing: 1.6,
                          color: kInkSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: 160,
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(kSealRed),
                          backgroundColor: kPrimaryBlue.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 右下角动态印章
            Positioned(
              right: 32,
              bottom: 48,
              child: FadeTransition(
                opacity: _fade,
                child: Opacity(
                  opacity: 0.85,
                  child: SealStampWidget(config: sealConfig, size: 64),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
