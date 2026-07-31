import '../../recording/domain/recording_models.dart';

enum CapabilityAvailability {
  available,
  permissionRequired,
  unsupported,
  error,
}

abstract interface class RecordingService {
  Stream<CapabilityAvailability> get availability;
  Stream<List<RecordingSegment>> watchSegments();
  Future<void> start();
  Future<void> stop();
}

abstract interface class LiveVideoService {
  Stream<CapabilityAvailability> get availability;
  Future<void> publish(Uri signalingEndpoint);
  Future<void> stop();
}

abstract interface class GoogleDataService {
  Stream<CapabilityAvailability> get availability;
  Future<void> authorize();
  Future<void> refreshCalendarAndTasks();
}

abstract interface class VoiceAssistantService {
  Stream<CapabilityAvailability> get availability;
  Future<void> startWakeWordDetection();
  Future<void> stop();
}

abstract interface class UploadTarget {
  String get id;
  Future<void> upload(RecordingSegment segment);
}
