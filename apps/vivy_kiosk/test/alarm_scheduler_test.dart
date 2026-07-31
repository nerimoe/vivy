import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/features/alarms/application/alarm_scheduler.dart';
import 'package:vivy_kiosk/features/alarms/domain/alarm.dart';

void main() {
  test('scheduler arms only the nearest enabled future alarm', () {
    final now = DateTime.utc(2026, 7, 30, 10);
    Duration? armedFor;
    void Function()? callback;
    final scheduler = AlarmScheduler(
      clock: () => now,
      timerFactory: (duration, handler) {
        armedFor = duration;
        callback = handler;
        return Timer(const Duration(days: 1), () {});
      },
    );
    VivyAlarm? fired;
    scheduler.arm([
      VivyAlarm(
        id: 'later',
        label: 'Later',
        scheduledAt: now.add(const Duration(hours: 2)),
      ),
      VivyAlarm(
        id: 'disabled',
        label: 'Disabled',
        scheduledAt: now.add(const Duration(minutes: 5)),
        enabled: false,
      ),
      VivyAlarm(
        id: 'next',
        label: 'Next',
        scheduledAt: now.add(const Duration(minutes: 30)),
      ),
    ], (alarm) => fired = alarm);

    expect(armedFor, const Duration(minutes: 30));
    callback!();
    expect(fired?.id, 'next');
    scheduler.dispose();
  });
}
