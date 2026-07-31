import 'package:flutter/foundation.dart';

enum SegmentState { writing, ready, uploading, uploaded, failed, dropped }

@immutable
class RecordingSegment {
  const RecordingSegment({
    required this.id,
    required this.startedAt,
    required this.bytes,
    required this.state,
    this.endedAt,
    this.path,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int bytes;
  final SegmentState state;
  final String? path;

  bool get isClosed => endedAt != null && state != SegmentState.writing;
}

@immutable
class RetentionPolicy {
  const RetentionPolicy({
    this.maxBytes = 20 * 1024 * 1024 * 1024,
    this.maxAge = const Duration(days: 7),
  });

  final int maxBytes;
  final Duration maxAge;

  Set<String> selectEvictions(
    Iterable<RecordingSegment> segments, {
    required DateTime now,
  }) {
    final retained = segments
        .where((segment) => segment.state != SegmentState.dropped)
        .toList();
    final eligible = retained.where((segment) => segment.isClosed).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final evictions = <String>{};
    final cutoff = now.subtract(maxAge);

    for (final segment in eligible) {
      if (segment.endedAt!.isBefore(cutoff)) evictions.add(segment.id);
    }

    var bytesAfterAgeEviction = retained
        .where((segment) => !evictions.contains(segment.id))
        .fold<int>(0, (total, segment) => total + segment.bytes);
    for (final segment in eligible) {
      if (bytesAfterAgeEviction <= maxBytes) break;
      if (evictions.add(segment.id)) {
        bytesAfterAgeEviction -= segment.bytes;
      }
    }
    return evictions;
  }
}

enum UploadState { queued, uploading, uploaded, failed, abandoned }

@immutable
class UploadJob {
  const UploadJob({
    required this.segmentId,
    this.state = UploadState.queued,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
  });

  final String segmentId;
  final UploadState state;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;

  UploadJob fail(String error, DateTime now) {
    final nextAttempts = attempts + 1;
    final seconds = (5 * (1 << (nextAttempts - 1))).clamp(5, 1800);
    return UploadJob(
      segmentId: segmentId,
      state: UploadState.failed,
      attempts: nextAttempts,
      nextAttemptAt: now.add(Duration(seconds: seconds)),
      lastError: error,
    );
  }
}
