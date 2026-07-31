import 'package:flutter/widgets.dart';

const _englishWeekdays = <String>[
  '',
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN',
];

const _chineseWeekdays = <String>['', '一', '二', '三', '四', '五', '六', '日'];

const _japaneseWeekdays = <String>['', '月', '火', '水', '木', '金', '土', '日'];

/// Returns a compact weekday label that follows the device language.
String compactWeekdayLabel(Locale locale, int weekday) {
  if (weekday < DateTime.monday || weekday > DateTime.sunday) {
    throw ArgumentError.value(weekday, 'weekday', 'must be between 1 and 7');
  }
  final labels = switch (locale.languageCode.toLowerCase()) {
    'zh' => _chineseWeekdays,
    'ja' => _japaneseWeekdays,
    _ => _englishWeekdays,
  };
  return labels[weekday];
}
