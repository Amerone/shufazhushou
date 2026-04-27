import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/app_clock.dart';

void main() {
  test('AppClock.now returns injected time', () {
    final clock = AppClock.fixed(DateTime(2026, 4, 27, 9, 30));

    expect(clock.now(), DateTime(2026, 4, 27, 9, 30));
    expect(clock.nowMs(), DateTime(2026, 4, 27, 9, 30).millisecondsSinceEpoch);
    expect(clock.todayKey(), '2026-04-27');
  });

  test('AppClock.system creates a non-null current time', () {
    final clock = AppClock.system();

    expect(clock.now(), isA<DateTime>());
    expect(clock.nowMs(), isA<int>());
  });
}
