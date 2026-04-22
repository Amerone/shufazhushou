import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';

/// Shared AsyncValue wrapper for standard loading/error/data rendering.
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget Function()? loadingBuilder;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;
  final VoidCallback? onRetry;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: loadingBuilder ?? () => const _DefaultLoading(),
      error:
          errorBuilder ??
          (error, stackTrace) => _DefaultError(error: error, onRetry: onRetry),
    );
  }
}

/// Sliver version of [AsyncValueWidget].
class AsyncValueSliverWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  const AsyncValueSliverWidget({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: _DefaultLoading(),
      ),
      error: (error, stackTrace) => SliverFillRemaining(
        hasScrollBody: false,
        child: _DefaultError(error: error, onRetry: onRetry),
      ),
    );
  }
}

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: '正在加载',
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator.adaptive(semanticsLabel: '正在加载'),
        ),
      ),
    );
  }
}

class _DefaultError extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const _DefaultError({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _friendlyMessage(error);

    return Semantics(
      container: true,
      liveRegion: true,
      label: '加载失败，$message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: kSealRed.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: kInkSecondary,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _friendlyMessage(Object error) {
    final message = error.toString();
    if (message.contains('数据库')) {
      return '数据访问出现问题，请重试';
    }
    if (message.contains('网络') || message.contains('Socket')) {
      return '网络连接异常';
    }
    return '操作失败，请稍后重试';
  }
}
