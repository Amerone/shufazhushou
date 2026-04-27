import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/theme.dart';

class QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const QuickActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: kInkSecondary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white.withValues(alpha: 0.56),
      side: BorderSide(color: kInkSecondary.withValues(alpha: 0.14)),
    );
  }
}

class QuickEntryStudentLoading extends StatelessWidget {
  const QuickEntryStudentLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '正在加载学生列表',
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator.adaptive(),
              SizedBox(height: 14),
              Text('正在加载学生列表...'),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickEntryStudentLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const QuickEntryStudentLoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kRed.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kRed.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: kRed.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 10),
              Text(
                '学生列表加载失败',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: kRed,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '请重新加载后再选择学员记课。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const QuickInfoPill({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? kInkSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: resolvedColor == kInkSecondary ? null : resolvedColor,
              fontWeight: resolvedColor == kInkSecondary
                  ? null
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class QuickEntryPickerField extends StatelessWidget {
  final String label;
  final String semanticsLabel;
  final String semanticsHint;
  final String value;
  final Future<void> Function() onTap;
  final IconData? trailingIcon;

  const QuickEntryPickerField({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.semanticsHint,
    required this.value,
    required this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    void handleTap() => unawaited(onTap());

    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: semanticsHint,
      value: value,
      onTap: handleTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: handleTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.56),
            ),
            child: trailingIcon == null
                ? Text(value)
                : Row(
                    children: [
                      Expanded(child: Text(value)),
                      Icon(trailingIcon, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
