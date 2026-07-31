import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class RecordingSettings {
  const RecordingSettings({this.maxCacheGb = 20});

  final int maxCacheGb;

  int get maxCacheBytes => maxCacheGb * 1024 * 1024 * 1024;
}

final recordingSettingsProvider =
    AsyncNotifierProvider<RecordingSettingsController, RecordingSettings>(
      RecordingSettingsController.new,
    );

class RecordingSettingsController extends AsyncNotifier<RecordingSettings> {
  static const _maxCacheGbKey = 'recording_max_cache_gb';

  @override
  Future<RecordingSettings> build() async {
    return loadRecordingSettings();
  }

  Future<void> setMaxCacheGb(int value) async {
    final normalized = value.clamp(1, 20).toInt();
    final next = RecordingSettings(maxCacheGb: normalized);
    state = AsyncData(next);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_maxCacheGbKey, normalized);
  }
}

Future<RecordingSettings> loadRecordingSettings() async {
  final preferences = await SharedPreferences.getInstance();
  final value = preferences.getInt('recording_max_cache_gb') ?? 20;
  return RecordingSettings(maxCacheGb: value.clamp(1, 20).toInt());
}
