import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/alarm_repository.dart';
import '../domain/alarm.dart';
import 'alarm_scheduler.dart';

final activeAlarmProvider = NotifierProvider<ActiveAlarmController, VivyAlarm?>(
  ActiveAlarmController.new,
);

class ActiveAlarmController extends Notifier<VivyAlarm?> {
  @override
  VivyAlarm? build() => null;

  void show(VivyAlarm alarm) => state = alarm;
  void clear() => state = null;
}

final alarmsProvider = AsyncNotifierProvider<AlarmController, List<VivyAlarm>>(
  AlarmController.new,
);

class AlarmController extends AsyncNotifier<List<VivyAlarm>> {
  late final AlarmRepository _repository;
  late final AlarmScheduler _scheduler;

  @override
  Future<List<VivyAlarm>> build() async {
    _repository = AlarmRepository();
    _scheduler = AlarmScheduler();
    ref.onDispose(_scheduler.dispose);
    final alarms = await _repository.load();
    _arm(alarms);
    return alarms;
  }

  Future<void> create({required String label, required DateTime at}) async {
    final alarms = [...state.value ?? const <VivyAlarm>[]];
    alarms.add(VivyAlarm(id: const Uuid().v4(), label: label, scheduledAt: at));
    alarms.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    state = AsyncData(alarms);
    await _repository.save(alarms);
    _arm(alarms);
  }

  Future<void> complete(String id) async {
    final alarms = (state.value ?? const <VivyAlarm>[])
        .where((alarm) => alarm.id != id)
        .toList();
    state = AsyncData(alarms);
    ref.read(activeAlarmProvider.notifier).clear();
    await _repository.save(alarms);
    _arm(alarms);
  }

  Future<void> snooze(VivyAlarm alarm) async {
    final alarms = (state.value ?? const <VivyAlarm>[])
        .where((item) => item.id != alarm.id)
        .toList();
    alarms.add(
      alarm.copyWith(
        scheduledAt: DateTime.now().add(Duration(minutes: alarm.snoozeMinutes)),
      ),
    );
    alarms.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    state = AsyncData(alarms);
    ref.read(activeAlarmProvider.notifier).clear();
    await _repository.save(alarms);
    _arm(alarms);
  }

  void _arm(List<VivyAlarm> alarms) {
    _scheduler.arm(alarms, ref.read(activeAlarmProvider.notifier).show);
  }
}
