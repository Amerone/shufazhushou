import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/shared/theme.dart';
import 'package:moyun/shared/widgets/time_wheel_picker.dart';

void main() {
  testWidgets('time wheel picker exposes explicit action semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: Center(child: _TimePickerHarness())),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final cancelNode = tester.getSemantics(find.bySemanticsLabel('取消开始时间选择'));
      expect(cancelNode.flagsCollection.isButton, isTrue);
      expect(
        cancelNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      final confirmNode = tester.getSemantics(
        find.bySemanticsLabel('确认开始时间选择'),
      );
      expect(confirmNode.hint, '使用当前选中的时间');
      expect(confirmNode.flagsCollection.isButton, isTrue);
      expect(
        confirmNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      await tester.tap(find.bySemanticsLabel('确认开始时间选择'));
      await tester.pumpAndSettle();

      expect(find.text('09:30'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}

class _TimePickerHarness extends StatefulWidget {
  const _TimePickerHarness();

  @override
  State<_TimePickerHarness> createState() => _TimePickerHarnessState();
}

class _TimePickerHarnessState extends State<_TimePickerHarness> {
  TimeOfDay? _picked;

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          picked == null
              ? 'none'
              : '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
        ),
        ElevatedButton(
          onPressed: () async {
            final next = await showTimeWheelPicker(
              context: context,
              initialTime: const TimeOfDay(hour: 9, minute: 30),
              label: '开始时间',
            );
            if (!mounted || next == null) return;
            setState(() => _picked = next);
          },
          child: const Text('open'),
        ),
      ],
    );
  }
}
