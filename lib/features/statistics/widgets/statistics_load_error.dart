import 'package:flutter/material.dart';

import '../../../shared/theme.dart';

const String _errorFallbackMessage = '请稍后重试。';
const List<String> _errorPrefixes = [
  'Exception:',
  'FormatException:',
  'StateError:',
  'Bad state:',
];

String formatStatisticsError(Object error) {
  var message = error.toString().trim();
  if (message.isEmpty) return _errorFallbackMessage;

  for (final prefix in _errorPrefixes) {
    if (!message.startsWith(prefix)) continue;
    message = message.substring(prefix.length).trim();
  }

  return message.isEmpty ? _errorFallbackMessage : message;
}

String buildStatisticsErrorMessage(String section, Object error) {
  final detail = formatStatisticsError(error);
  if (detail == _errorFallbackMessage) {
    return '$section加载失败，请稍后重试。';
  }
  return '$section加载失败：$detail';
}

class StatisticsLoadError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const StatisticsLoadError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kRed.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.error_outline_rounded, color: kRed, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kRed,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
