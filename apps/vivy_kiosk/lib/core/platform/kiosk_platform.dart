import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MotionSensorKind { accelerometer, gyroscope }

class DeviceMotionSample {
  const DeviceMotionSample({
    required this.kind,
    required this.x,
    required this.y,
    required this.z,
  });

  final MotionSensorKind kind;
  final double x;
  final double y;
  final double z;
}

class KioskPlatform {
  static const _methods = MethodChannel('dev.vivy/kiosk');
  static const _light = EventChannel('dev.vivy/ambient_light');
  static const _motion = EventChannel('dev.vivy/device_motion');

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<double> ambientLux() {
    if (!isAndroid) return const Stream.empty();
    return _light
        .receiveBroadcastStream()
        .where((value) => value is num)
        .map((value) => (value as num).toDouble());
  }

  Stream<DeviceMotionSample> deviceMotion() {
    if (!isAndroid) return const Stream.empty();
    return _motion
        .receiveBroadcastStream()
        .where((value) {
          return value is Map &&
              value['type'] is String &&
              value['x'] is num &&
              value['y'] is num &&
              value['z'] is num;
        })
        .map((value) {
          final map = value as Map;
          return DeviceMotionSample(
            kind: map['type'] == 'gyroscope'
                ? MotionSensorKind.gyroscope
                : MotionSensorKind.accelerometer,
            x: (map['x'] as num).toDouble(),
            y: (map['y'] as num).toDouble(),
            z: (map['z'] as num).toDouble(),
          );
        });
  }

  Future<void> enterPinnedMode() async {
    if (!isAndroid) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await _methods.invokeMethod<void>('enterPinnedMode');
  }
}

final kioskPlatformProvider = Provider<KioskPlatform>((_) => KioskPlatform());

final ambientLuxProvider = StreamProvider<double>(
  (ref) => ref.watch(kioskPlatformProvider).ambientLux(),
);

final deviceMotionProvider = StreamProvider<DeviceMotionSample>(
  (ref) => ref.watch(kioskPlatformProvider).deviceMotion(),
);

final platformBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(kioskPlatformProvider).enterPinnedMode();
});
