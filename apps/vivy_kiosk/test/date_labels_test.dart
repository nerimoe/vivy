import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/features/kiosk/presentation/date_labels.dart';

void main() {
  test('uses compact weekday labels for supported device languages', () {
    expect(compactWeekdayLabel(const Locale('en'), DateTime.saturday), 'SAT');
    expect(compactWeekdayLabel(const Locale('zh'), DateTime.saturday), '六');
    expect(compactWeekdayLabel(const Locale('ja'), DateTime.saturday), '土');
  });

  test('rejects an invalid weekday number', () {
    expect(
      () => compactWeekdayLabel(const Locale('en'), 0),
      throwsArgumentError,
    );
  });
}
