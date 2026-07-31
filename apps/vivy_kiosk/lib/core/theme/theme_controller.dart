import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';

enum VivyThemeMode { automatic, light, dark }

enum ThemeSource { ambientLight, sunlight, manual, system }

enum VivyPalette { indigo, teal, coral, amber, blue }

enum ClockTypeface {
  sculpted,
  serif,
  rounded,
  outline,
  layered,
  inline,
  stencil,
  techno,
}

enum ClockColorRole { primary, secondary, tertiary, surface }

@immutable
class ThemeState {
  const ThemeState({
    this.mode = VivyThemeMode.automatic,
    this.brightness = Brightness.light,
    this.source = ThemeSource.system,
    this.palette = VivyPalette.indigo,
    this.clockTypeface = ClockTypeface.sculpted,
    this.clockWeight = 500,
    this.dateTypeface = ClockTypeface.rounded,
    this.clockColorRole = ClockColorRole.primary,
    this.latitude,
    this.longitude,
    this.manualUntil,
  });

  final VivyThemeMode mode;
  final Brightness brightness;
  final ThemeSource source;
  final VivyPalette palette;
  final ClockTypeface clockTypeface;
  final int clockWeight;
  final ClockTypeface dateTypeface;
  final ClockColorRole clockColorRole;
  final double? latitude;
  final double? longitude;
  final DateTime? manualUntil;

  ThemeState copyWith({
    VivyThemeMode? mode,
    Brightness? brightness,
    ThemeSource? source,
    VivyPalette? palette,
    ClockTypeface? clockTypeface,
    int? clockWeight,
    ClockTypeface? dateTypeface,
    ClockColorRole? clockColorRole,
    double? latitude,
    double? longitude,
    DateTime? manualUntil,
    bool clearManualUntil = false,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      brightness: brightness ?? this.brightness,
      source: source ?? this.source,
      palette: palette ?? this.palette,
      clockTypeface: clockTypeface ?? this.clockTypeface,
      clockWeight: clockWeight ?? this.clockWeight,
      dateTypeface: dateTypeface ?? this.dateTypeface,
      clockColorRole: clockColorRole ?? this.clockColorRole,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      manualUntil: clearManualUntil ? null : manualUntil ?? this.manualUntil,
    );
  }
}

class ThemePolicyEngine {
  const ThemePolicyEngine();

  Brightness fromLux(double lux, Brightness current) {
    if (lux < 30) return Brightness.dark;
    if (lux > 80) return Brightness.light;
    return current;
  }

  Brightness fromSun({
    required DateTime now,
    required double latitude,
    required double longitude,
  }) {
    final solar = getSunriseSunset(
      latitude,
      longitude,
      now.timeZoneOffset,
      DateTime(now.year, now.month, now.day),
    );
    final wallClock = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    return wallClock.isAfter(solar.sunrise) && wallClock.isBefore(solar.sunset)
        ? Brightness.light
        : Brightness.dark;
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeState>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeState> {
  static const _modeKey = 'theme_mode';
  static const _latitudeKey = 'latitude';
  static const _longitudeKey = 'longitude';
  static const _paletteKey = 'material_palette';
  static const _clockTypefaceKey = 'clock_typeface';
  static const _clockWeightKey = 'clock_weight';
  static const _dateTypefaceKey = 'date_typeface';
  static const _clockColorRoleKey = 'clock_color_role';
  final ThemePolicyEngine _engine = const ThemePolicyEngine();
  Timer? _manualTimer;

  @override
  ThemeState build() {
    ref.onDispose(() => _manualTimer?.cancel());
    Future<void>.microtask(_restore);
    return const ThemeState();
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final modeIndex = preferences.getInt(_modeKey) ?? 0;
    final latitude = preferences.getDouble(_latitudeKey);
    final longitude = preferences.getDouble(_longitudeKey);
    final paletteIndex = preferences.getInt(_paletteKey) ?? 0;
    final typefaceIndex = preferences.getInt(_clockTypefaceKey) ?? 0;
    final clockWeight = preferences.getInt(_clockWeightKey) ?? 500;
    final dateTypefaceIndex =
        preferences.getInt(_dateTypefaceKey) ?? ClockTypeface.rounded.index;
    final colorRoleIndex = preferences.getInt(_clockColorRoleKey) ?? 0;
    state = state.copyWith(
      mode: VivyThemeMode
          .values[modeIndex.clamp(0, VivyThemeMode.values.length - 1)],
      latitude: latitude,
      longitude: longitude,
      palette: VivyPalette
          .values[paletteIndex.clamp(0, VivyPalette.values.length - 1)],
      clockTypeface: ClockTypeface
          .values[typefaceIndex.clamp(0, ClockTypeface.values.length - 1)],
      clockWeight: clockWeight.clamp(100, 900),
      dateTypeface: ClockTypeface
          .values[dateTypefaceIndex.clamp(0, ClockTypeface.values.length - 1)],
      clockColorRole: ClockColorRole
          .values[colorRoleIndex.clamp(0, ClockColorRole.values.length - 1)],
    );
    refreshFromSun();
  }

  Future<void> setAutomatic() async {
    _manualTimer?.cancel();
    state = state.copyWith(
      mode: VivyThemeMode.automatic,
      source: ThemeSource.sunlight,
      clearManualUntil: true,
    );
    await _persistMode();
    refreshFromSun();
  }

  Future<void> setTemporary(Brightness brightness) async {
    final until = DateTime.now().add(const Duration(hours: 2));
    state = state.copyWith(
      mode: brightness == Brightness.light
          ? VivyThemeMode.light
          : VivyThemeMode.dark,
      brightness: brightness,
      source: ThemeSource.manual,
      manualUntil: until,
    );
    await _persistMode();
    _manualTimer?.cancel();
    _manualTimer = Timer(const Duration(hours: 2), setAutomatic);
  }

  void updateLux(double lux) {
    if (state.mode != VivyThemeMode.automatic) return;
    state = state.copyWith(
      brightness: _engine.fromLux(lux, state.brightness),
      source: ThemeSource.ambientLight,
    );
  }

  Future<void> setLocation(double latitude, double longitude) async {
    state = state.copyWith(latitude: latitude, longitude: longitude);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_latitudeKey, latitude);
    await preferences.setDouble(_longitudeKey, longitude);
    refreshFromSun();
  }

  Future<void> setPalette(VivyPalette palette) async {
    state = state.copyWith(palette: palette);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_paletteKey, palette.index);
  }

  Future<void> setClockTypeface(ClockTypeface typeface) async {
    state = state.copyWith(clockTypeface: typeface);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_clockTypefaceKey, typeface.index);
  }

  Future<void> setClockWeight(int weight) async {
    final normalized = ((weight.clamp(100, 900) / 100).round() * 100).clamp(
      100,
      900,
    );
    state = state.copyWith(clockWeight: normalized);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_clockWeightKey, normalized);
  }

  Future<void> setDateTypeface(ClockTypeface typeface) async {
    state = state.copyWith(dateTypeface: typeface);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_dateTypefaceKey, typeface.index);
  }

  Future<void> setClockColorRole(ClockColorRole role) async {
    state = state.copyWith(clockColorRole: role);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_clockColorRoleKey, role.index);
  }

  void refreshFromSun([DateTime? value]) {
    if (state.mode != VivyThemeMode.automatic ||
        state.latitude == null ||
        state.longitude == null) {
      return;
    }
    state = state.copyWith(
      brightness: _engine.fromSun(
        now: value ?? DateTime.now(),
        latitude: state.latitude!,
        longitude: state.longitude!,
      ),
      source: ThemeSource.sunlight,
    );
  }

  Future<void> _persistMode() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_modeKey, state.mode.index);
  }
}
