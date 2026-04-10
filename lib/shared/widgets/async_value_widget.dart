import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';

/// Shared AsyncValue wrapper for standard loading/error/data rendering.
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget Function()? loadingBuilder;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: loadingBuilder ?? () => const _DefaultLoading(),
      error: errorBuilder ?? (error, stackTrace) => _DefaultError(error: error),
    );
  }
}

/// Sliver version of [AsyncValueWidget].
class AsyncValueSliverWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  const AsyncValueSliverWidget({
    super.key,
    required this.value,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const SliverFillRemaining(child: _DefaultLoading()),
      error: (error, stackTrace) =>
          SliverFillRemaining(child: _DefaultError(error: error)),
    );
  }
}

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }
}

class _DefaultError extends StatelessWidget {
  final Object error;

  const _DefaultError({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: kSealRed.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              '\u52a0\u8f7d\u5931\u8d25',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _friendlyMessage(error),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: kInkSecondary),
            ),
          ],
        ),
      ),
    );
  }

  static String _friendlyMessage(Object error) {
    final message = error.toString();
    if (message.contains('\u6570\u636e\u5e93')) {
      return '\u6570\u636e\u8bbf\u95ee\u51fa\u73b0\u95ee\u9898\uff0c\u8bf7\u91cd\u8bd5';
    }
    if (message.contains('\u7f51\u7edc') || message.contains('Socket')) {
      return '\u7f51\u7edc\u8fde\u63a5\u5f02\u5e38';
    }
    return '\u64cd\u4f5c\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
  }
}
