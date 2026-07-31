import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/voice_tools.dart';

class RealtimeClient {
  RealtimeClient({required this.tools});

  static const model = 'gpt-realtime-1.5';
  final VoiceToolExecutor tools;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  WebSocket? _socket;

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect(String apiKey) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'OpenAI Realtime is only available on Android Vivy',
      );
    }
    final socket = await WebSocket.connect(
      'wss://api.openai.com/v1/realtime?model=$model',
      headers: {'Authorization': 'Bearer $apiKey'},
    );
    _socket = socket;
    socket.listen(_handleMessage, onError: _events.addError, onDone: close);
    _send({
      'type': 'session.update',
      'session': {
        'type': 'realtime',
        'instructions':
            'You are Vivy, a concise household assistant. Use tools for every device-changing action.',
        'tools': vivyRealtimeTools,
        'tool_choice': 'auto',
      },
    });
  }

  void appendPcm16(String base64Audio) {
    _send({'type': 'input_audio_buffer.append', 'audio': base64Audio});
  }

  void commitAudio() {
    _send({'type': 'input_audio_buffer.commit'});
    _send({'type': 'response.create'});
  }

  Future<void> _handleMessage(dynamic raw) async {
    if (raw is! String) return;
    final event = jsonDecode(raw) as Map<String, dynamic>;
    _events.add(event);
    if (event['type'] != 'response.function_call_arguments.done') return;
    try {
      final call = VoiceToolCall.parse(
        callId: event['call_id'] as String,
        name: event['name'] as String,
        argumentsJson: event['arguments'] as String,
      );
      final output = await tools.execute(call);
      _send({
        'type': 'conversation.item.create',
        'item': {
          'type': 'function_call_output',
          'call_id': call.callId,
          'output': jsonEncode(output),
        },
      });
      _send({'type': 'response.create'});
    } on Object catch (error) {
      _events.addError(error);
    }
  }

  void _send(Map<String, Object?> event) {
    final socket = _socket;
    if (socket == null) throw StateError('Realtime session is not connected');
    socket.add(jsonEncode(event));
  }

  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    await socket?.close();
    if (!_events.isClosed) await _events.close();
  }
}
