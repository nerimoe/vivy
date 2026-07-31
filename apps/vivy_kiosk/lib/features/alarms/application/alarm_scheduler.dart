import 'dart:async';

import '../domain/alarm.dart';

typedef AlarmTimerFactory =
    Timer Function(Duration duration, void Function() callback);

class AlarmScheduler {
  AlarmScheduler({DateTime Function()? clock, AlarmTimerFactory? timerFactory})
    : _clock = clock ?? DateTime.now,
      _timerFactory =
          timerFactory ?? ((duration, callback) => Timer(duration, callback));

  final DateTime Function() _clock;
  final AlarmTimerFactory _timerFactory;
  Timer? _timer;

  void arm(List<VivyAlarm> alarms, void Function(VivyAlarm alarm) onFire) {
    _timer?.cancel();
    final now = _clock();
    final pending =
        alarms
            .where((alarm) => alarm.enabled && alarm.scheduledAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (pending.isEmpty) return;
    final next = pending.first;
    _timer = _timerFactory(
      next.scheduledAt.difference(now),
      () => onFire(next),
    );
  }

  void dispose() => _timer?.cancel();
}
