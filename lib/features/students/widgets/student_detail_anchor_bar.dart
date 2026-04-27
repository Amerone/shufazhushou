import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_card.dart';

enum StudentDetailAnchor { finance, payments, attendance }

class StudentDetailAnchorBar extends StatelessWidget {
  const StudentDetailAnchorBar({super.key, required this.onSelect});

  final ValueChanged<StudentDetailAnchor> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '\u5b66\u751f\u6863\u6848\u5feb\u6377\u5bfc\u822a',
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final buttonWidth = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 3;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StudentDetailAnchorButton(
                  width: buttonWidth,
                  icon: Icons.account_balance_wallet_outlined,
                  label: '\u8d39\u7528',
                  onPressed: () => onSelect(StudentDetailAnchor.finance),
                ),
                _StudentDetailAnchorButton(
                  width: buttonWidth,
                  icon: Icons.payments_outlined,
                  label: '\u7f34\u8d39',
                  onPressed: () => onSelect(StudentDetailAnchor.payments),
                ),
                _StudentDetailAnchorButton(
                  width: buttonWidth,
                  icon: Icons.fact_check_outlined,
                  label: '\u51fa\u52e4',
                  onPressed: () => onSelect(StudentDetailAnchor.attendance),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudentDetailAnchorButton extends StatelessWidget {
  const _StudentDetailAnchorButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
