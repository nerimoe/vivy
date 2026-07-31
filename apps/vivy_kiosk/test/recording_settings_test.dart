import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/features/recording/application/recording_settings.dart';

void main() {
  test('converts the user cache limit from GB to bytes', () {
    const settings = RecordingSettings(maxCacheGb: 6);

    expect(settings.maxCacheBytes, 6 * 1024 * 1024 * 1024);
  });
}
