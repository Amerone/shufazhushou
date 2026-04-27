import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_clock.dart';

final appClockProvider = Provider<AppClock>((ref) {
  return AppClock.system();
});
