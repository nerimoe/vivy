import 'package:flutter/foundation.dart';

@immutable
class VivyAlarm {
  const VivyAlarm({
    required this.id,
    required this.label,
    required this.scheduledAt,
    this.snoozeMinutes = 10,
    this.enabled = true,
  });

  factory VivyAlarm.fromJson(Map<String, Object?> json) => VivyAlarm(
    id: json['id']! as String,
    label: json['label']! as String,
    scheduledAt: DateTime.parse(json['scheduled_at']! as String),
    snoozeMinutes: json['snooze_minutes']! as int,
    enabled: json['enabled']! as bool,
  );

  final String id;
  final String label;
  final DateTime scheduledAt;
  final int snoozeMinutes;
  final bool enabled;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'scheduled_at': scheduledAt.toIso8601String(),
    'snooze_minutes': snoozeMinutes,
    'enabled': enabled,
  };

  VivyAlarm copyWith({DateTime? scheduledAt, bool? enabled}) => VivyAlarm(
    id: id,
    label: label,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    snoozeMinutes: snoozeMinutes,
    enabled: enabled ?? this.enabled,
  );
}
