import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../application/recording_settings.dart';
import '../../integrations/domain/integration_ports.dart';
import '../domain/recording_models.dart';
import 'segment_store.dart';

class CameraSegmentRecorder implements RecordingService {
  CameraSegmentRecorder({
    this.segmentDuration = const Duration(minutes: 2),
    SegmentStore? store,
    RetentionPolicy? retention,
  }) : _store = store ?? SegmentStore(),
       _retention = retention ?? const RetentionPolicy();

  final Duration segmentDuration;
  final SegmentStore _store;
  RetentionPolicy _retention;
  final _availability = StreamController<CapabilityAvailability>.broadcast();
  final _segments = StreamController<List<RecordingSegment>>.broadcast();
  final List<RecordingSegment> _index = [];
  CameraController? _camera;
  Timer? _rotation;
  DateTime? _segmentStartedAt;
  bool _rotating = false;

  CameraController? get camera => _camera;

  @override
  Stream<CapabilityAvailability> get availability => _availability.stream;

  @override
  Stream<List<RecordingSegment>> watchSegments() => _segments.stream;

  void setMaxCacheBytes(int bytes) {
    _retention = RetentionPolicy(maxBytes: bytes, maxAge: _retention.maxAge);
    unawaited(enforceStoredRetention());
  }

  Future<void> enforceStoredRetention() async {
    final stored = await _store.list();
    var total = stored.fold<int>(0, (sum, segment) => sum + segment.bytes);
    final oldestFirst = stored.toList()
      ..sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
    for (final segment in oldestFirst) {
      if (total <= _retention.maxBytes) break;
      await _store.delete(segment.path);
      total -= segment.bytes;
    }
  }

  Future<void> clearStoredRecordings() async {
    _rotation?.cancel();
    await _camera?.dispose();
    _camera = null;
    await _store.deleteAll();
    _index.clear();
    _segments.add(const <RecordingSegment>[]);
  }

  @override
  Future<void> start() async {
    if (_camera?.value.isRecordingVideo ?? false) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _availability.add(CapabilityAvailability.unsupported);
        return;
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      _camera = controller;
      await _startSegment();
      _availability.add(CapabilityAvailability.available);
    } on CameraException catch (error, stackTrace) {
      _availability.addError(error, stackTrace);
      _availability.add(CapabilityAvailability.permissionRequired);
      rethrow;
    }
  }

  Future<void> _startSegment() async {
    final camera = _camera;
    if (camera == null || camera.value.isRecordingVideo) return;
    _segmentStartedAt = DateTime.now();
    await camera.startVideoRecording();
    _rotation?.cancel();
    _rotation = Timer(segmentDuration, _rotate);
  }

  Future<void> _rotate() async {
    if (_rotating) return;
    _rotating = true;
    try {
      await _closeCurrentSegment();
      await _startSegment();
    } finally {
      _rotating = false;
    }
  }

  Future<void> _closeCurrentSegment() async {
    final camera = _camera;
    if (camera == null || !camera.value.isRecordingVideo) return;
    final file = await camera.stopVideoRecording();
    final endedAt = DateTime.now();
    final id = const Uuid().v4();
    final stored = await _store.save(id, file);
    final segment = RecordingSegment(
      id: id,
      startedAt: _segmentStartedAt ?? endedAt,
      endedAt: endedAt,
      bytes: stored.bytes,
      state: SegmentState.ready,
      path: stored.path,
    );
    _index.add(segment);
    await _applyRetention(endedAt);
    await enforceStoredRetention();
    _segments.add(List.unmodifiable(_index));
  }

  Future<void> _applyRetention(DateTime now) async {
    final evictions = _retention.selectEvictions(_index, now: now);
    for (var index = 0; index < _index.length; index++) {
      final segment = _index[index];
      if (!evictions.contains(segment.id)) continue;
      if (segment.path != null) await _store.delete(segment.path!);
      _index[index] = RecordingSegment(
        id: segment.id,
        startedAt: segment.startedAt,
        endedAt: segment.endedAt,
        bytes: 0,
        state: SegmentState.dropped,
        path: segment.path,
      );
    }
  }

  @override
  Future<void> stop() async {
    _rotation?.cancel();
    await _closeCurrentSegment();
    await _camera?.dispose();
    _camera = null;
    _availability.add(CapabilityAvailability.unsupported);
  }

  Future<void> dispose() async {
    await stop();
    await _availability.close();
    await _segments.close();
  }
}

final recordingServiceProvider = Provider<CameraSegmentRecorder>(
  (_) => CameraSegmentRecorder(),
);

final recordingBootstrapProvider = FutureProvider<CameraSegmentRecorder?>((
  ref,
) async {
  final supported = kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  if (!supported) return null;
  final service = ref.watch(recordingServiceProvider);
  ref.onDispose(service.dispose);
  final settings = await loadRecordingSettings();
  service.setMaxCacheBytes(settings.maxCacheBytes);
  await service.enforceStoredRetention();
  const clearRecordings = bool.fromEnvironment('VIVY_CLEAR_RECORDINGS');
  if (clearRecordings) await service.clearStoredRecordings();
  await service.start();
  return service;
});
