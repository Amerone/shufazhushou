import 'package:flutter/material.dart';

import '../../../shared/theme.dart';

class ExportMessageSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String labelText;
  final String hintText;
  final List<String> presetMessages;
  final ValueChanged<String> onPresetSelected;

  const ExportMessageSection({
    super.key,
    required this.controller,
    this.onChanged,
    required this.labelText,
    required this.hintText,
    required this.presetMessages,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLength: 200,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: labelText,
            counterText: '',
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presetMessages
                  .map(
                    (message) => ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: ActionChip(
                        label: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                        side: BorderSide(
                          color: kInkSecondary.withValues(alpha: 0.2),
                        ),
                        onPressed: () => onPresetSelected(message),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
