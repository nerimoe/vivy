import '../domain/voice_tools.dart';

class RealtimeClient {
  RealtimeClient({required VoiceToolExecutor tools});

  Stream<Map<String, dynamic>> get events => const Stream.empty();

  Future<void> connect(String apiKey) async {
    throw UnsupportedError('OpenAI Realtime is only available on Android Vivy');
  }

  Future<void> close() async {}
}
