import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/features/weather/data/weather_forecast.dart';

void main() {
  test('parses aligned Open-Meteo hourly values', () {
    final forecast = WeatherClient.parse({
      'hourly': {
        'time': ['2026-07-31T22:00', '2026-07-31T23:00'],
        'temperature_2m': [28.4, 27.2],
        'precipitation_probability': [10, 65],
        'weather_code': [1, 61],
      },
    });

    expect(forecast.hours, hasLength(2));
    expect(forecast.hours.first.temperature, 28.4);
    expect(forecast.hours.last.condition, WeatherCondition.rain);
  });

  test('surfaces near-term rain as a concise notice', () {
    final now = DateTime(2026, 7, 31, 22, 20);
    final forecast = WeatherForecast([
      HourlyWeather(
        time: DateTime(2026, 7, 31, 22),
        temperature: 28,
        precipitationProbability: 10,
        weatherCode: 1,
      ),
      HourlyWeather(
        time: DateTime(2026, 7, 31, 23),
        temperature: 27,
        precipitationProbability: 70,
        weatherCode: 61,
      ),
    ]);

    expect(forecast.notice(now)?.text, 'Rain near 23:00');
  });

  test('summarizes rain without exposing hourly details', () {
    final forecast = WeatherForecast([
      HourlyWeather(
        time: DateTime(2026, 7, 31, 12),
        temperature: 28,
        precipitationProbability: 70,
        weatherCode: 61,
      ),
      HourlyWeather(
        time: DateTime(2026, 8, 1, 12),
        temperature: 29,
        precipitationProbability: 10,
        weatherCode: 1,
      ),
    ]);

    expect(forecast.advisory(DateTime(2026, 7, 31, 9))?.text, '今天可能下雨');
  });

  test('summarizes a high-temperature day', () {
    final forecast = WeatherForecast([
      HourlyWeather(
        time: DateTime(2026, 7, 31, 14),
        temperature: 33,
        precipitationProbability: 0,
        weatherCode: 0,
      ),
    ]);

    expect(forecast.advisory(DateTime(2026, 7, 31, 9))?.text, '今天外面气温偏高');
  });
}
