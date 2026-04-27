import '../../shared/constants.dart';

typedef DateTimeFactory = DateTime Function();

class AppClock {
  final DateTimeFactory _now;

  const AppClock({required DateTimeFactory now}) : _now = now;

  factory AppClock.system() {
    return AppClock(now: DateTime.now);
  }

  factory AppClock.fixed(DateTime value) {
    return AppClock(now: () => value);
  }

  DateTime now() => _now();

  int nowMs() => now().millisecondsSinceEpoch;

  String todayKey() => formatDate(now());
}
