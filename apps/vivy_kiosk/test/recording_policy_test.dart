import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/features/recording/domain/recording_models.dart';

void main() {
  RecordingSegment segment(
    String id,
    DateTime startedAt,
    int bytes, {
    SegmentState state = SegmentState.ready,
  }) {
    return RecordingSegment(
      id: id,
      startedAt: startedAt,
      endedAt: state == SegmentState.writing
          ? null
          : startedAt.add(const Duration(minutes: 2)),
      bytes: bytes,
      state: state,
    );
  }

  test('retention removes expired closed segments but never active writer', () {
    final now = DateTime.utc(2026, 7, 30);
    const policy = RetentionPolicy(maxBytes: 1000, maxAge: Duration(days: 7));
    final result = policy.selectEvictions([
      segment('expired', now.subtract(const Duration(days: 8)), 100),
      segment(
        'writing',
        now.subtract(const Duration(days: 8)),
        100,
        state: SegmentState.writing,
      ),
      segment('current', now.subtract(const Duration(hours: 1)), 100),
    ], now: now);

    expect(result, {'expired'});
  });

  test(
    'capacity removes oldest closed segments including unuploaded files',
    () {
      final now = DateTime.utc(2026, 7, 30);
      const policy = RetentionPolicy(maxBytes: 200, maxAge: Duration(days: 7));
      final result = policy.selectEvictions([
        segment(
          'old-failed',
          now.subtract(const Duration(hours: 3)),
          150,
          state: SegmentState.failed,
        ),
        segment('middle', now.subtract(const Duration(hours: 2)), 100),
        segment('new', now.subtract(const Duration(hours: 1)), 100),
      ], now: now);

      expect(result, {'old-failed'});
    },
  );

  test('upload retry uses capped exponential backoff', () {
    final now = DateTime.utc(2026, 7, 30);
    var job = const UploadJob(segmentId: 'segment');
    job = job.fail('offline', now);
    expect(job.nextAttemptAt, now.add(const Duration(seconds: 5)));
    for (var index = 0; index < 20; index++) {
      job = job.fail('offline', now);
    }
    expect(job.nextAttemptAt, now.add(const Duration(minutes: 30)));
  });
}
