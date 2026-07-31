import 'dart:math' as math;
import 'dart:ui';

import '../platform/kiosk_platform.dart';

class ClockMotionSpring {
  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
  Offset _gravity = Offset.zero;
  bool _hasGravity = false;

  static const double maxDisplacement = 14;
  static const double _maxVelocity = 52;

  void addSample(DeviceMotionSample sample) {
    switch (sample.kind) {
      case MotionSensorKind.accelerometer:
        final reading = Offset(sample.x, sample.y);
        if (!_hasGravity) {
          _gravity = reading;
          _hasGravity = true;
          return;
        }
        _gravity = Offset.lerp(_gravity, reading, 0.08)!;
        final movement = reading - _gravity;
        if (movement.distance < 0.16) return;
        // Sensor Y points toward the top of the display; Flutter Y points down.
        // Inertia moves opposite the screen-space acceleration.
        _addVelocity(Offset(-movement.dx, movement.dy) * 2.8);
      case MotionSensorKind.gyroscope:
        final rotation = Offset(-sample.y, -sample.x);
        if (rotation.distance < 0.035) return;
        _addVelocity(rotation * 14);
    }
  }

  void step(double elapsedSeconds) {
    final dt = elapsedSeconds.clamp(0.0, 1 / 30).toDouble();
    const stiffness = 42.0;
    const damping = 10.5;
    final acceleration = -position * stiffness - velocity * damping;
    velocity += acceleration * dt;
    position += velocity * dt;
    if (position.distance > maxDisplacement) {
      position = _limit(position, maxDisplacement);
      velocity *= 0.72;
    }
    if (position.distance < 0.015 && velocity.distance < 0.04) {
      position = Offset.zero;
      velocity = Offset.zero;
    }
  }

  bool get isSettled => position == Offset.zero && velocity == Offset.zero;

  void _addVelocity(Offset impulse) {
    velocity = _limit(velocity + impulse, _maxVelocity);
  }

  Offset _limit(Offset value, double maximum) {
    final magnitude = value.distance;
    if (magnitude <= maximum || magnitude == 0) return value;
    return value * (maximum / math.max(magnitude, 0.0001));
  }
}
