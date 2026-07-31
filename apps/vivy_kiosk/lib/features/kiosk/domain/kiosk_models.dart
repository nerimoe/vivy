import 'package:flutter/foundation.dart';

enum ReminderKind { alarm, calendar, task }

enum NotificationSource { weather, alarm, reminder, desktop }

@immutable
class NotificationStatusItem {
  const NotificationStatusItem({
    required this.id,
    required this.source,
    required this.message,
    required this.priority,
    required this.createdAt,
    this.title,
    this.note,
  });

  final String id;
  final NotificationSource source;
  final String message;
  final int priority;
  final DateTime createdAt;
  final String? title;
  final String? note;
}

enum RecordingStatus { active, recovering, error, disabled }

@immutable
class UpcomingItem {
  const UpcomingItem({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.kind,
    this.note,
  });

  final String id;
  final String title;
  final DateTime dueAt;
  final ReminderKind kind;
  final String? note;
}

UpcomingItem? approachingItem(Iterable<UpcomingItem> source, DateTime now) {
  final matches = approachingItems(source, now);
  return matches.isEmpty ? null : matches.first;
}

List<UpcomingItem> approachingItems(
  Iterable<UpcomingItem> items,
  DateTime now,
) {
  final sorted = items.toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  return [
    for (final item in sorted)
      if (_isApproaching(item, now)) item,
  ];
}

bool _isApproaching(UpcomingItem item, DateTime now) {
  final until = item.dueAt.difference(now);
  final leadTime = switch (item.kind) {
    ReminderKind.alarm => const Duration(minutes: 30),
    ReminderKind.calendar => const Duration(minutes: 20),
    ReminderKind.task => const Duration(minutes: 15),
  };
  return until >= const Duration(minutes: -5) && until <= leadTime;
}

@immutable
class RecordingSummary {
  const RecordingSummary({
    this.status = RecordingStatus.active,
    this.usedBytes = 0,
    this.capacityBytes = 20 * 1024 * 1024 * 1024,
    this.segmentMinutes = 2,
  });

  final RecordingStatus status;
  final int usedBytes;
  final int capacityBytes;
  final int segmentMinutes;
}

@immutable
class KioskState {
  const KioskState({
    required this.upcoming,
    this.recording = const RecordingSummary(),
  });

  final List<UpcomingItem> upcoming;
  final RecordingSummary recording;
}
