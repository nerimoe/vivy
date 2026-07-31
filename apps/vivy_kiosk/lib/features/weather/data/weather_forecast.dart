import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/theme_controller.dart';
import 'weather_http_client.dart';

enum WeatherCondition { clear, partlyCloudy, cloudy, fog, rain, snow, storm }

class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final int precipitationProbability;
  final int weatherCode;

  WeatherCondition get condition => weatherConditionForCode(weatherCode);
}

class WeatherNotice {
  const WeatherNotice({required this.text, required this.condition});

  final String text;
  final WeatherCondition condition;
}

class WeatherAdvisory {
  const WeatherAdvisory({required this.text, required this.priority});

  final String text;
  final int priority;
}

class WeatherForecast {
  const WeatherForecast(this.hours);

  final List<HourlyWeather> hours;

  List<HourlyWeather> upcoming(DateTime now, {int count = 4}) {
    final threshold = now.subtract(const Duration(minutes: 30));
    return hours
        .where((hour) => !hour.time.isBefore(threshold))
        .take(count)
        .toList();
  }

  WeatherAdvisory? advisory(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayHours = _dayHours(today);
    final tomorrowHours = _dayHours(tomorrow);
    final todayRain = _hasRain(todayHours);
    final tomorrowRain = _hasRain(tomorrowHours);
    final todayHot = _isHot(todayHours);
    final tomorrowHot = _isHot(tomorrowHours);
    if (todayRain) {
      return const WeatherAdvisory(text: '今天可能下雨', priority: 58);
    }
    if (todayHot) {
      return const WeatherAdvisory(text: '今天外面气温偏高', priority: 54);
    }
    if (tomorrowRain) {
      return const WeatherAdvisory(text: '明天可能下雨', priority: 46);
    }
    if (tomorrowHot) {
      return const WeatherAdvisory(text: '明天气温可能偏高', priority: 42);
    }
    return null;
  }

  List<HourlyWeather> _dayHours(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return hours
        .where((hour) => !hour.time.isBefore(start) && hour.time.isBefore(end))
        .toList();
  }

  static bool _hasRain(Iterable<HourlyWeather> hours) => hours.any(
    (hour) =>
        hour.precipitationProbability >= 60 ||
        hour.condition == WeatherCondition.rain ||
        hour.condition == WeatherCondition.storm,
  );

  static bool _isHot(Iterable<HourlyWeather> hours) =>
      hours.any((hour) => hour.temperature >= 32);

  WeatherNotice? notice(DateTime now) {
    final next = upcoming(now, count: 5);
    if (next.isEmpty) return null;
    for (final hour in next) {
      if (hour.condition == WeatherCondition.storm) {
        return WeatherNotice(
          text: 'Storm near ${_hourLabel(hour.time)}',
          condition: hour.condition,
        );
      }
    }
    for (final hour in next) {
      if (hour.precipitationProbability >= 60 ||
          hour.condition == WeatherCondition.rain) {
        return WeatherNotice(
          text: 'Rain near ${_hourLabel(hour.time)}',
          condition: WeatherCondition.rain,
        );
      }
    }
    final change = next.last.temperature - next.first.temperature;
    if (change.abs() >= 5) {
      return WeatherNotice(
        text:
            '${change.isNegative ? 'Cooling' : 'Warming'} ${change.abs().round()}° by ${_hourLabel(next.last.time)}',
        condition: next.last.condition,
      );
    }
    return null;
  }

  static String _hourLabel(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:00';
}

WeatherCondition weatherConditionForCode(int code) {
  if (code == 0) return WeatherCondition.clear;
  if (code <= 2) return WeatherCondition.partlyCloudy;
  if (code == 3) return WeatherCondition.cloudy;
  if (code == 45 || code == 48) return WeatherCondition.fog;
  if (code >= 95) return WeatherCondition.storm;
  if (code >= 71 && code <= 86) return WeatherCondition.snow;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return WeatherCondition.rain;
  }
  return WeatherCondition.cloudy;
}

class WeatherClient {
  WeatherClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherForecast> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(5),
      'longitude': longitude.toStringAsFixed(5),
      'hourly': 'temperature_2m,precipitation_probability,weather_code',
      'forecast_days': '2',
      'timezone': 'auto',
    });
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Weather returned ${response.statusCode}',
        uri,
      );
    }
    return parse(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void close() => _client.close();

  static WeatherForecast parse(Map<String, dynamic> json) {
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly == null) throw const FormatException('Missing hourly weather');
    final times = hourly['time'] as List<dynamic>? ?? const [];
    final temperatures = hourly['temperature_2m'] as List<dynamic>? ?? const [];
    final precipitation =
        hourly['precipitation_probability'] as List<dynamic>? ?? const [];
    final codes = hourly['weather_code'] as List<dynamic>? ?? const [];
    final count = [
      times.length,
      temperatures.length,
      precipitation.length,
      codes.length,
    ].reduce((a, b) => a < b ? a : b);
    return WeatherForecast([
      for (var index = 0; index < count; index += 1)
        HourlyWeather(
          time: DateTime.parse(times[index] as String),
          temperature: (temperatures[index] as num).toDouble(),
          precipitationProbability: (precipitation[index] as num).round(),
          weatherCode: (codes[index] as num).round(),
        ),
    ]);
  }
}

final weatherForecastProvider = FutureProvider<WeatherForecast?>((ref) async {
  final location = ref.watch(
    themeControllerProvider.select(
      (state) => (state.latitude, state.longitude),
    ),
  );
  if (location.$1 == null || location.$2 == null) return null;
  final refresh = Timer(const Duration(minutes: 30), ref.invalidateSelf);
  ref.onDispose(refresh.cancel);
  final client = WeatherClient(client: await createWeatherHttpClient());
  ref.onDispose(client.close);
  return client.fetch(latitude: location.$1!, longitude: location.$2!);
});
