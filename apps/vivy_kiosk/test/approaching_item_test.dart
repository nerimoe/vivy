import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/features/kiosk/domain/kiosk_models.dart';

void main() {
  final now = DateTime(2026, 7, 31, 12);

  UpcomingItem item(ReminderKind kind, Duration offset) => UpcomingItem(
    id: '${kind.name}-${offset.inMinutes}',
    title: kind.name,
    dueAt: now.add(offset),
    kind: kind,
  );

  test('keeps distant items off the clock home', () {
    expect(
      approachingItem([
        item(ReminderKind.alarm, const Duration(minutes: 31)),
        item(ReminderKind.calendar, const Duration(minutes: 21)),
        item(ReminderKind.task, const Duration(minutes: 16)),
      ], now),
      isNull,
    );
  });

  test('selects the nearest item inside its lead window', () {
    final task = item(ReminderKind.task, const Duration(minutes: 12));
    final alarm = item(ReminderKind.alarm, const Duration(minutes: 24));

    expect(approachingItem([alarm, task], now), same(task));
  });

  test('keeps multiple approaching items available for rotation', () {
    final alarm = item(ReminderKind.alarm, const Duration(minutes: 24));
    final task = item(ReminderKind.task, const Duration(minutes: 12));

    expect(approachingItems([alarm, task], now), [task, alarm]);
  });

  test('removes stale items after a short grace period', () {
    expect(
      approachingItem([
        item(ReminderKind.alarm, const Duration(minutes: -6)),
      ], now),
      isNull,
    );
  });
}
