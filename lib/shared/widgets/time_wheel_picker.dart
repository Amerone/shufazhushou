import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/interaction_feedback.dart';

/// Apple-style wheel time picker displayed in a bottom sheet.
/// Returns a [TimeOfDay] or null if cancelled.
Future<TimeOfDay?> showTimeWheelPicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? label,
}) async {
  TimeOfDay selected = initialTime;
  final pickerLabel = label ?? '时间';

  void cancel(BuildContext ctx) => Navigator.pop(ctx);
  void confirm(BuildContext ctx) => Navigator.pop(ctx, selected);

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: kPaperCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => LayoutBuilder(
      builder: (context, constraints) {
        final sheetHeight = (constraints.maxHeight * 0.48)
            .clamp(280.0, 360.0)
            .toDouble();

        return SafeArea(
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kInkSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Semantics(
                        button: true,
                        label: '取消$pickerLabel选择',
                        onTap: () => cancel(ctx),
                        child: ExcludeSemantics(
                          child: TextButton(
                            onPressed: () => cancel(ctx),
                            child: Text(
                              '取消',
                              style: TextStyle(
                                color: kInkSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (label != null)
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF3A352B),
                          ),
                        ),
                      Semantics(
                        button: true,
                        label: '确认$pickerLabel选择',
                        hint: '使用当前选中的时间',
                        onTap: () => confirm(ctx),
                        child: ExcludeSemantics(
                          child: TextButton(
                            onPressed: () => confirm(ctx),
                            child: const Text(
                              '确定',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(
                      2024,
                      1,
                      1,
                      initialTime.hour,
                      initialTime.minute,
                    ),
                    onDateTimeChanged: (dt) {
                      unawaited(InteractionFeedback.selection(ctx));
                      selected = TimeOfDay(hour: dt.hour, minute: dt.minute);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
