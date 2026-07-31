import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/kiosk_models.dart';

final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});

final kioskControllerProvider = NotifierProvider<KioskController, KioskState>(
  KioskController.new,
);

class KioskController extends Notifier<KioskState> {
  @override
  KioskState build() {
    final now = DateTime.now();
    return KioskState(
      upcoming: [
        UpcomingItem(
          id: 'morning-alarm',
          title: 'Morning alarm',
          dueAt: DateTime(now.year, now.month, now.day, 7, 30).add(
            now.hour >= 7 && now.minute >= 30
                ? const Duration(days: 1)
                : Duration.zero,
          ),
          kind: ReminderKind.alarm,
        ),
        UpcomingItem(
          id: 'focus-session',
          title: 'Focus session',
          dueAt: now.add(const Duration(hours: 2)),
          kind: ReminderKind.calendar,
          note: 'Desk',
        ),
        UpcomingItem(
          id: 'plants',
          title: 'Water the plants',
          dueAt: now.add(const Duration(hours: 5)),
          kind: ReminderKind.task,
        ),
      ]..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
    );
  }

  void complete(String id) {
    state = KioskState(
      upcoming: state.upcoming.where((item) => item.id != id).toList(),
      recording: state.recording,
    );
  }

  void snooze(String id, [Duration duration = const Duration(minutes: 10)]) {
    state = KioskState(
      upcoming:
          state.upcoming
              .map(
                (item) => item.id == id
                    ? UpcomingItem(
                        id: item.id,
                        title: item.title,
                        dueAt: DateTime.now().add(duration),
                        kind: item.kind,
                        note: item.note,
                      )
                    : item,
              )
              .toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
      recording: state.recording,
    );
  }
}
