import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Apple-style wheel time picker displayed in a bottom sheet.
/// Returns a [TimeOfDay] or null if cancelled.
Future<TimeOfDay?> showTimeWheelPicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? label,
}) async {
  TimeOfDay selected = initialTime;

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: kPaperCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: 300,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      '取消',
                      style: TextStyle(color: kInkSecondary, fontWeight: FontWeight.w500),
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
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: const Text(
                      '确定',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
                initialDateTime: DateTime(2024, 1, 1, initialTime.hour, initialTime.minute),
                onDateTimeChanged: (dt) {
                  HapticFeedback.selectionClick();
                  selected = TimeOfDay(hour: dt.hour, minute: dt.minute);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
