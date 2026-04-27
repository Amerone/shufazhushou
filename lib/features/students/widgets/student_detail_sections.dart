import 'package:flutter/material.dart';

import '../../../core/models/payment.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import 'student_attendance_record_card.dart';

class StudentSectionBlock extends StatelessWidget {
  final Key? anchorKey;
  final Widget child;

  const StudentSectionBlock({super.key, this.anchorKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(key: anchorKey, child: child);
  }
}

class StudentDetailSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String trailing;

  const StudentDetailSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final titleBlock = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ],
          ),
        );
        final trailingBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
          ),
          child: Text(
            trailing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: subtitle == null ? 26 : 44,
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              if (compact)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [titleBlock]),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: trailingBadge,
                      ),
                    ],
                  ),
                )
              else ...[
                titleBlock,
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: trailingBadge,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class StudentProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const StudentProfileBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class StudentDetailNoteCard extends StatelessWidget {
  final String note;

  const StudentDetailNoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '备注',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(note),
        ],
      ),
    );
  }
}

class StudentDetailInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const StudentDetailInfoChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kInkSecondary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kInkSecondary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (MediaQuery.sizeOf(context).width - 148).clamp(
                80.0,
                360.0,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class StudentDetailRefreshErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final String errorText;
  final String retryLabel;
  final VoidCallback onRetry;

  const StudentDetailRefreshErrorCard({
    super.key,
    required this.title,
    required this.message,
    required this.errorText,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sync_problem_outlined,
                  size: 18,
                  color: kOrange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(message, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      errorText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kInkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final action = TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined, size: 18),
            label: Text(retryLabel),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 8),
              action,
            ],
          );
        },
      ),
    );
  }
}

class StudentPaymentCard extends StatelessWidget {
  final Payment payment;
  final bool deleting;
  final VoidCallback onDelete;

  const StudentPaymentCard({
    super.key,
    required this.payment,
    required this.deleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final deleteAction = _StudentDangerActionButton(
            tooltip: '删除缴费记录',
            loading: deleting,
            onPressed: onDelete,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: kGreen,
                      size: 18,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已收',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '¥${payment.amount.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (compact) deleteAction,
                      ],
                    ),
                    const SizedBox(height: 8),
                    StudentDetailMetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: payment.paymentDate,
                    ),
                    if (payment.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(payment.note!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[const SizedBox(width: 10), deleteAction],
            ],
          );
        },
      ),
    );
  }
}

class _StudentDangerActionButton extends StatelessWidget {
  final String tooltip;
  final bool loading;
  final VoidCallback onPressed;

  const _StudentDangerActionButton({
    required this.tooltip,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_outline),
        color: kRed,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
