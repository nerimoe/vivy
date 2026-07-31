import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/core/theme/theme_controller.dart';

void main() {
  const engine = ThemePolicyEngine();

  test('ambient-light thresholds have a stable hysteresis band', () {
    expect(engine.fromLux(20, Brightness.light), Brightness.dark);
    expect(engine.fromLux(90, Brightness.dark), Brightness.light);
    expect(engine.fromLux(50, Brightness.dark), Brightness.dark);
    expect(engine.fromLux(50, Brightness.light), Brightness.light);
  });

  test('sunlight fallback distinguishes local day and night', () {
    const latitude = 35.6762;
    const longitude = 139.6503;
    final midday = DateTime(2026, 7, 30, 12);
    final midnight = DateTime(2026, 7, 30);

    expect(
      engine.fromSun(now: midday, latitude: latitude, longitude: longitude),
      Brightness.light,
    );
    expect(
      engine.fromSun(now: midnight, latitude: latitude, longitude: longitude),
      Brightness.dark,
    );
  });
}
