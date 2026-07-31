import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/alarm.dart';

class AlarmRepository {
  static const _key = 'vivy_alarms_v1';

  Future<List<VivyAlarm>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<Object?>;
    return decoded
        .cast<Map<String, Object?>>()
        .map(VivyAlarm.fromJson)
        .toList();
  }

  Future<void> save(List<VivyAlarm> alarms) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(alarms.map((alarm) => alarm.toJson()).toList()),
    );
  }
}
