import 'package:flutter/material.dart';

import '../../../core/utils/fee_calculator.dart';
import '../services/export_parent_snapshot_service.dart';
import '../../../shared/theme.dart';

Color _snapshotBalanceColor(LedgerBalanceState state) {
  switch (state) {
    case LedgerBalanceState.debt:
      return kRed;
    case LedgerBalanceState.settled:
      return kInkSecondary;
    case LedgerBalanceState.surplus:
      return kGreen;
  }
}

class ExportParentSnapshotCard extends StatelessWidget {
  final Future<ExportParentSnapshot> future;

  const ExportParentSnapshotCard({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<ExportParentSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Semantics(
            container: true,
            liveRegion: true,
            label: '正在整理家长摘要',
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: kInkSecondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text('整理摘要...', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Semantics(
            container: true,
            liveRegion: true,
            label: '家长摘要加载失败，可继续导出',
            child: ExcludeSemantics(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kRed.withValues(alpha: 0.12)),
                ),
                child: Text(
                  '摘要加载失败，可继续导出。',
                  style: theme.textTheme.bodySmall?.copyWith(color: kRed),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 440;
              final itemWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SnapshotMetric(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '余额',
                      value: data.balanceLabel,
                      color: _snapshotBalanceColor(data.balanceState),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SnapshotMetric(
                      icon: Icons.schedule_outlined,
                      label: '下次课',
                      value: data.nextLessonLabel,
                      color: kSealRed,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SnapshotMetric(
                      icon: Icons.trending_up_outlined,
                      label: '进步点',
                      value: data.progressPoint,
                      color: kGreen,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SnapshotMetric(
                      icon: Icons.track_changes_outlined,
                      label: '待巩固点',
                      value: data.attentionPoint,
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _SnapshotMetric(
                      icon: Icons.update_outlined,
                      label: '数据截止',
                      value: data.dataFreshness,
                      color: kInkSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SnapshotMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SnapshotMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
