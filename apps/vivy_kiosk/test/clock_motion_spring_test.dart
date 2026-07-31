import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/core/motion/clock_motion_spring.dart';
import 'package:vivy_kiosk/core/platform/kiosk_platform.dart';

void main() {
  test('motion impulse stays bounded and springs back to rest', () {
    final spring = ClockMotionSpring();

    spring.addSample(
      const DeviceMotionSample(
        kind: MotionSensorKind.gyroscope,
        x: 1.2,
        y: -0.8,
        z: 0,
      ),
    );
    expect(spring.velocity.distance, greaterThan(0));

    for (var frame = 0; frame < 600; frame += 1) {
      spring.step(1 / 60);
      expect(
        spring.position.distance,
        lessThanOrEqualTo(ClockMotionSpring.maxDisplacement + 0.001),
      );
    }

    expect(spring.isSettled, isTrue);
  });

  test('accelerometer gravity is filtered before movement is applied', () {
    final spring = ClockMotionSpring();
    const gravity = DeviceMotionSample(
      kind: MotionSensorKind.accelerometer,
      x: 0,
      y: 9.8,
      z: 0,
    );

    spring.addSample(gravity);
    expect(spring.velocity, Offset.zero);
    spring.addSample(
      const DeviceMotionSample(
        kind: MotionSensorKind.accelerometer,
        x: 1.6,
        y: 9.1,
        z: 0,
      ),
    );
    expect(spring.velocity.distance, greaterThan(0));
    expect(spring.velocity.dx, lessThan(0));
  });
}
